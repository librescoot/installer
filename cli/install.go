package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	usbVID   = "0525"
	pidRNDIS = "a4a2"
	pidUMS   = "a4a5"

	// On-MDB staging area. Anything under /data/installer/ is cleaned up at
	// the finish phase via a single `rm -rf`.
	mdbInstallerDir = "/data/installer"
)

type Installer struct {
	mdbHost     string
	mdbPassword string
	cacheDir    string

	imagePath    string // local MDB sdimg(.gz)
	bmapPath     string
	dbcImagePath string
	dbcBmapPath  string
	osmTilesPath string
	valTilesPath string

	channel    string
	releaseTag string
	region     string
	language   string

	dryRun  bool
	yes     bool // skip confirmations
	timeout time.Duration
}

// runFull is the legacy one-shot path: phase 1 + phase 2 + phase 3 with
// user prompts at the handoffs. Identical UX to the original CLI but built
// on top of the phase helpers so state is tracked the same way.
func (inst *Installer) runFull() error {
	if err := inst.runPhase1(); err != nil {
		return err
	}
	if err := inst.runPhase2(); err != nil {
		return err
	}
	return inst.runPhase3()
}

// Phase 1: bring the MDB up to a Librescoot install. Ends with the MDB
// booted, /data/installer prepared, and state.json written. After this the
// operator can unplug the USB cable and walk to the next scooter — the
// trampoline (phase 2) is still required, but the host can be elsewhere
// when phase 2 starts as long as it can reach the MDB again over USB.
func (inst *Installer) runPhase1() error {
	logStep("Phase 1: MDB flash + Librescoot boot")

	if inst.imagePath == "" {
		return fmt.Errorf("no MDB image path set (resolved release missing?)")
	}
	info, err := os.Stat(inst.imagePath)
	if err != nil {
		return fmt.Errorf("firmware image not found: %w", err)
	}
	logInfo("MDB image: %s (%s)", filepath.Base(inst.imagePath), formatBytes(info.Size()))

	logStep("Detecting MDB...")
	if err := inst.detectMDB(); err != nil {
		return fmt.Errorf("MDB detection failed: %w", err)
	}

	logStep("Connecting to MDB via SSH...")
	deviceInfo, err := inst.getMDBInfo()
	if err != nil {
		return fmt.Errorf("SSH connection failed: %w", err)
	}
	logInfo("Firmware: %s", deviceInfo["version"])
	if serial, ok := deviceInfo["serial"]; ok && serial != "" {
		logInfo("Serial:   %s", serial)
	}

	// Disable hazards we hit on locked scooters: auto-standby, alarm, and
	// indicator drift. Best-effort — settings keys may not exist on stock
	// images. lsc returns non-zero if a key is unknown; ignore that.
	inst.silenceVehicleHazards()

	// Hold the USB gadget online for the whole install. On Librescoot
	// re-flashes this prevents vehicle-service from kicking us off the
	// bus mid-flash. On stock images the key doesn't exist and lsc fails
	// harmlessly.
	inst.mdbSSH("lsc set scooter.usb0-policy always-on 2>/dev/null; true")

	// Stop power manager early so suspend can't interrupt the flash.
	inst.mdbSSH("systemctl stop librescoot-pm 2>/dev/null; systemctl stop pm-service 2>/dev/null; true")

	logStep("Configuring bootloader for mass storage mode...")
	if inst.dryRun {
		logInfo("[dry-run] would upload fw_setenv and configure bootcmd")
	} else if err := inst.configureBootloader(); err != nil {
		return fmt.Errorf("bootloader configuration failed: %w", err)
	}

	// Persist intent before reboot so resume can find us.
	st := &State{
		Phase:      PhaseMDBPrepped,
		Channel:    inst.channel,
		ReleaseTag: inst.releaseTag,
		Serial:     deviceInfo["serial"],
		MDBVersion: deviceInfo["version"],
		Region:     inst.region,
		Language:   inst.language,
	}
	if !inst.dryRun {
		_ = inst.saveState(st)
	}

	logStep("Rebooting MDB into mass storage mode...")
	if inst.dryRun {
		logInfo("[dry-run] would reboot MDB")
	} else if err := inst.rebootMDB(); err != nil {
		return fmt.Errorf("reboot failed: %w", err)
	}

	logStep("Waiting for USB mass storage device...")
	if inst.dryRun {
		logInfo("[dry-run] would wait for USB %s:%s", usbVID, pidUMS)
	} else if err := inst.waitForMassStorage(120 * time.Second); err != nil {
		return fmt.Errorf("mass storage not detected: %w", err)
	}

	var devicePath string
	logStep("Finding block device...")
	if inst.dryRun {
		devicePath = "/dev/sdX"
		logInfo("[dry-run] would find block device")
	} else {
		devicePath, err = inst.findBlockDevice()
		if err != nil {
			return fmt.Errorf("block device not found: %w", err)
		}
		logInfo("Device: %s", devicePath)
	}

	logStep("Flashing firmware...")
	logInfo("Image:  %s", filepath.Base(inst.imagePath))
	logInfo("Device: %s", devicePath)
	if inst.dryRun {
		logInfo("[dry-run] would flash image to device")
	} else {
		if !inst.yes {
			fmt.Print("\nThis will ERASE ALL DATA on the MDB. Continue? [y/N] ")
			var confirm string
			fmt.Scanln(&confirm)
			if strings.ToLower(confirm) != "y" {
				return fmt.Errorf("aborted by user")
			}
		}
		if err := inst.flashImage(devicePath); err != nil {
			return fmt.Errorf("flashing failed: %w", err)
		}
	}

	st.Phase = PhaseMDBFlashed
	if !inst.dryRun {
		// We can't write state to the freshly flashed image — there's no
		// MDB running right now, the kernel is in u-boot UMS. Defer the
		// state save until after boot.
	}

	logStep("Flash complete. Power cycle the MDB to boot into Librescoot.")
	logInfo("Press Enter after the MDB has been power cycled and USB reconnected.")
	if !inst.dryRun && !inst.yes {
		fmt.Print("\nPress Enter to continue...")
		fmt.Scanln()
	}

	logStep("Waiting for MDB to boot into Librescoot...")
	if inst.dryRun {
		logInfo("[dry-run] would wait for RNDIS + stable ping")
	} else if err := inst.waitForBoot(10 * time.Minute); err != nil {
		logWarn("Boot wait failed: %v", err)
		logInfo("The MDB may still be booting. Try pinging %s manually.", inst.mdbHost)
		return err
	}

	// MDB has booted into Librescoot. Re-establish SSH (which now uses the
	// Librescoot-shipped password — same one we already have) and write the
	// state file for the first time on the new rootfs.
	info2, _ := inst.getMDBInfo()
	if info2 != nil {
		logInfo("Firmware: %s", info2["version"])
		if name, ok := info2["pretty_name"]; ok {
			logInfo("OS:       %s", name)
		}
		if info2["version"] != "" {
			st.MDBVersion = info2["version"]
		}
		if info2["serial"] != "" {
			st.Serial = info2["serial"]
		}
	}

	// Re-apply USB gadget hold on the fresh image (stock policy is `auto`).
	inst.mdbSSH("lsc set scooter.usb0-policy always-on 2>/dev/null; true")
	inst.silenceVehicleHazards()

	st.Phase = PhaseMDBBooted
	if !inst.dryRun {
		_ = inst.saveState(st)
	}

	logStep("Phase 1 complete — MDB is up at Librescoot.")
	logInfo("Next: librescoot-install phase2  (kicks off DBC trampoline)")
	return nil
}

// Phase 2: stage DBC artifacts and kick off the trampoline. The trampoline
// runs detached via nohup; this command then either watches for completion
// or exits immediately depending on --wait.
func (inst *Installer) runPhase2() error {
	logStep("Phase 2: DBC trampoline flash + tile install")

	if err := inst.detectMDB(); err != nil {
		return fmt.Errorf("MDB detection failed: %w", err)
	}
	if _, err := inst.getMDBInfo(); err != nil {
		return fmt.Errorf("SSH connection failed: %w", err)
	}

	st, err := inst.loadState()
	if err != nil || st.Phase == PhaseFresh {
		logWarn("No state file on MDB — assuming this is a manual phase2 invocation")
		st = &State{Phase: PhaseMDBBooted, Channel: inst.channel, ReleaseTag: inst.releaseTag}
	}

	// Idempotency: if trampoline already running or done, jump to monitoring.
	out, _ := inst.mdbSSHOnce("test -f /data/installer/trampoline-status && cat /data/installer/trampoline-status | head -1")
	switch strings.TrimSpace(strings.SplitN(out, "\n", 2)[0]) {
	case "success":
		logInfo("Trampoline already reported success — moving on.")
		st.Phase = PhaseTrampolineOK
		_ = inst.saveState(st)
		return nil
	case "rebooting":
		logInfo("Trampoline is mid-flight (rebooting DBC).")
		return inst.monitorTrampoline()
	}

	inst.silenceVehicleHazards()
	inst.mdbSSH("lsc set scooter.usb0-policy always-on 2>/dev/null; true")
	inst.mdbSSH("systemctl stop librescoot-pm 2>/dev/null; systemctl stop pm-service 2>/dev/null; true")

	if inst.dbcImagePath == "" {
		return fmt.Errorf("no DBC image set — pass --dbc-image or --channel")
	}
	dbcInfo, err := os.Stat(inst.dbcImagePath)
	if err != nil {
		return fmt.Errorf("DBC image not found: %w", err)
	}
	logInfo("DBC image: %s (%s)", filepath.Base(inst.dbcImagePath), formatBytes(dbcInfo.Size()))

	if err := inst.stageDBCArtifacts(st); err != nil {
		return fmt.Errorf("staging DBC artifacts: %w", err)
	}
	st.Phase = PhaseDBCStaged
	_ = inst.saveState(st)

	if err := inst.kickOffTrampoline(st); err != nil {
		return fmt.Errorf("starting trampoline: %w", err)
	}
	st.Phase = PhaseTrampolineRun
	_ = inst.saveState(st)

	logInfo("Trampoline running (detached). You can disconnect the USB cable now.")
	if !inst.yes {
		return nil
	}
	return inst.monitorTrampoline()
}

// Phase 3: finish — channel persistence, unlock, keycard, reboot.
func (inst *Installer) runPhase3() error {
	logStep("Phase 3: finish")

	if err := inst.detectMDB(); err != nil {
		return fmt.Errorf("MDB detection failed: %w", err)
	}
	if _, err := inst.getMDBInfo(); err != nil {
		return fmt.Errorf("SSH connection failed: %w", err)
	}

	st, _ := inst.loadState()
	if st == nil {
		st = &State{}
	}

	// Guard against finishing on top of a failed trampoline.
	if st.Phase == PhaseTrampolineErr {
		logWarn("Trampoline previously reported an error. Continuing anyway.")
	} else if st.Phase != PhaseTrampolineOK && st.Phase != PhaseFinished {
		// Probe live status before refusing.
		out, _ := inst.mdbSSHOnce("test -f /data/installer/trampoline-status && cat /data/installer/trampoline-status | head -1")
		head := strings.TrimSpace(strings.SplitN(out, "\n", 2)[0])
		if head != "success" {
			return fmt.Errorf("trampoline has not completed successfully yet (status: %q). Run phase2 first.", head)
		}
		st.Phase = PhaseTrampolineOK
	}

	channel := st.Channel
	if inst.channel != "" {
		channel = inst.channel
	}

	logStep("Resetting installer-only settings...")
	// Drop the auto-standby/alarm-disabled overrides we installed; settings-service
	// repopulates defaults from schema on next start.
	inst.mdbSSH("rm -f /data/settings.toml && systemctl restart librescoot-settings 2>/dev/null; true")
	time.Sleep(2 * time.Second)

	if inst.language != "" {
		logStep("Persisting dashboard language: %s", inst.language)
		inst.mdbSSH(fmt.Sprintf("lsc set dashboard.language %s 2>/dev/null; true", shellQuote(inst.language)))
	}

	if channel != "" {
		logStep("Persisting OTA channel: %s", channel)
		inst.mdbSSH(fmt.Sprintf("lsc ota channel %s 2>/dev/null; true", shellQuote(channel)))
	}

	logStep("Unlocking scooter (allows BLE pairing)...")
	inst.mdbSSH("lsc unlock 2>/dev/null; true")

	logStep("Starting librescoot-keycard for automatic master teach-in...")
	inst.mdbSSH("systemctl unmask librescoot-keycard 2>/dev/null; systemctl start librescoot-keycard 2>/dev/null; true")

	logStep("Restoring power manager + USB gadget policy, then rebooting MDB...")
	// One detached shell so reboot can take down usb0 mid-script without
	// killing the cleanup. Mirrors fix(installer): stage under /data/installer/.
	finishCmd := strings.Join([]string{
		"systemctl restart librescoot-pm 2>/dev/null",
		"lsc set scooter.usb0-policy auto 2>/dev/null",
		"rm -rf /data/installer",
		"rm -f /data/onboot.sh.bak /data/trampoline.sh /data/trampoline.log /data/trampoline-status",
		"rm -f /data/trampoline-stdout.log /data/trampoline-journal.log /data/stop-error-signals.sh",
		"rm -f /data/librescoot-flasher /data/.fresh-flash",
		"sync",
		"reboot",
	}, "; ")
	if !inst.dryRun {
		_ = inst.mdbSSHDetached(finishCmd)
	} else {
		logInfo("[dry-run] finish command: %s", finishCmd)
	}

	st.Phase = PhaseFinished
	if !inst.dryRun {
		// state.json gets wiped along with /data/installer above. Best-effort save.
		_ = inst.saveState(st)
	}

	logStep("Phase 3 complete — scooter is rebooting into normal operation.")
	return nil
}

// silenceVehicleHazards disables auto-standby + the alarm so a half-flashed
// scooter doesn't suspend on us, blink hazards, or start screaming. All
// best-effort — failures are expected on stock images that lack lsc.
func (inst *Installer) silenceVehicleHazards() {
	inst.mdbSSH(strings.Join([]string{
		"lsc set scooter.auto-standby-seconds 0 2>/dev/null; true",
		"lsc set alarm.enabled false 2>/dev/null; true",
	}, "; "))
}
