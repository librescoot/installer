package main

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

//go:embed assets/fw_setenv
var fwSetenvBin []byte

//go:embed assets/fw_env.config
var fwEnvConfig []byte

const (
	mdbSSHOpts = "-o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ConnectTimeout=10"
	usbVID     = "0525"
	pidRNDIS   = "a4a2"
	pidUMS     = "a4a5"
)

type Installer struct {
	mdbHost     string
	mdbPassword string
	cacheDir    string
	imagePath   string
	dryRun      bool
}

func (inst *Installer) Run() error {
	logStep("Checking firmware image...")
	info, err := os.Stat(inst.imagePath)
	if err != nil {
		return fmt.Errorf("firmware image not found: %w", err)
	}
	logInfo("%s (%s)", filepath.Base(inst.imagePath), formatBytes(info.Size()))

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

	// Stop power manager to prevent suspend/hibernate during flashing
	inst.mdbSSH("systemctl stop librescoot-pm pm-service 2>/dev/null")

	logStep("Configuring bootloader for mass storage mode...")
	if inst.dryRun {
		logInfo("[dry-run] would upload fw_setenv and configure bootcmd")
	} else {
		if err := inst.configureBootloader(); err != nil {
			return fmt.Errorf("bootloader configuration failed: %w", err)
		}
	}

	logStep("Rebooting MDB into mass storage mode...")
	if inst.dryRun {
		logInfo("[dry-run] would reboot MDB")
	} else {
		if err := inst.rebootMDB(); err != nil {
			return fmt.Errorf("reboot failed: %w", err)
		}
	}

	logStep("Waiting for USB mass storage device...")
	if inst.dryRun {
		logInfo("[dry-run] would wait for USB 0525:a4a5")
	} else {
		if err := inst.waitForMassStorage(120 * time.Second); err != nil {
			return fmt.Errorf("mass storage not detected: %w", err)
		}
	}

	logStep("Finding block device...")
	var devicePath string
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
		fmt.Print("\nThis will ERASE ALL DATA on the MDB. Continue? [y/N] ")
		var confirm string
		fmt.Scanln(&confirm)
		if strings.ToLower(confirm) != "y" {
			return fmt.Errorf("aborted by user")
		}
		if err := inst.flashImage(devicePath); err != nil {
			return fmt.Errorf("flashing failed: %w", err)
		}
	}

	logStep("Flash complete. Power cycle the MDB to boot into LibreScoot.")
	logInfo("Press Enter after the MDB has been power cycled and USB reconnected.")
	if !inst.dryRun {
		fmt.Print("\nPress Enter to continue...")
		fmt.Scanln()
	}

	logStep("Waiting for MDB to boot into LibreScoot...")
	if inst.dryRun {
		logInfo("[dry-run] would wait for RNDIS + stable ping")
	} else {
		if err := inst.waitForBoot(10 * time.Minute); err != nil {
			logWarn("Boot wait failed: %v", err)
			logInfo("The MDB may still be booting. Try pinging %s manually.", inst.mdbHost)
		} else {
			info, err := inst.getMDBInfo()
			if err != nil {
				logInfo("MDB is up but couldn't read version: %v", err)
			} else {
				logInfo("Firmware: %s", info["version"])
				if name, ok := info["pretty_name"]; ok {
					logInfo("OS:       %s", name)
				}
			}
		}
	}

	logStep("Done! LibreScoot has been installed.")
	return nil
}

// detectMDB checks if the MDB is reachable in RNDIS ethernet mode.
func (inst *Installer) detectMDB() error {
	// Check for RNDIS USB device
	out, err := run("lsusb", "-d", usbVID+":"+pidRNDIS)
	if err == nil && strings.TrimSpace(out) != "" {
		logInfo("Found RNDIS device: %s", strings.TrimSpace(out))
	} else {
		logWarn("RNDIS USB device not found in lsusb, checking network...")
	}

	// Configure network interface if needed
	if err := inst.ensureNetworkInterface(); err != nil {
		logWarn("Network config: %v", err)
	}

	// Ping MDB
	if _, err := run("ping", "-c", "1", "-W", "3", inst.mdbHost); err != nil {
		return fmt.Errorf("MDB at %s is not reachable (ping failed)", inst.mdbHost)
	}
	logInfo("MDB reachable at %s", inst.mdbHost)
	return nil
}

// ensureNetworkInterface finds and configures the RNDIS network interface.
func (inst *Installer) ensureNetworkInterface() error {
	// Check if already reachable
	if _, err := run("ping", "-c", "1", "-W", "2", inst.mdbHost); err == nil {
		return nil
	}

	// Find the RNDIS interface
	iface, err := inst.findRNDISInterface()
	if err != nil {
		return err
	}
	logInfo("Found interface: %s", iface)

	// Bring it up and assign IP
	runSudo("ip", "link", "set", iface, "up")
	out, err := runSudo("ip", "addr", "add", "192.168.7.50/24", "dev", iface)
	if err != nil && !strings.Contains(out+err.Error(), "File exists") {
		return fmt.Errorf("failed to configure %s: %w", iface, err)
	}

	// Wait for link
	time.Sleep(2 * time.Second)
	return nil
}

func (inst *Installer) findRNDISInterface() (string, error) {
	out, err := run("ip", "-o", "link", "show")
	if err != nil {
		return "", err
	}

	for _, line := range strings.Split(out, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		iface := strings.TrimSuffix(fields[1], ":")
		// Look for usb0, enx*, enp*s*u* patterns (USB RNDIS)
		if iface == "usb0" || strings.HasPrefix(iface, "enx") {
			// Verify it's a CDC Ethernet / RNDIS device
			driverPath := fmt.Sprintf("/sys/class/net/%s/device/driver", iface)
			if target, err := os.Readlink(driverPath); err == nil {
				driver := filepath.Base(target)
				if driver == "cdc_ether" || driver == "rndis_host" || driver == "cdc_subset" {
					return iface, nil
				}
			}
			// Accept enx* even without driver check
			if strings.HasPrefix(iface, "enx") {
				return iface, nil
			}
		}
	}
	return "", fmt.Errorf("no RNDIS network interface found")
}

func (inst *Installer) mdbSSH(cmd string) (string, error) {
	sshCmd := fmt.Sprintf("sshpass -p '%s' ssh %s root@%s '%s'",
		inst.mdbPassword, mdbSSHOpts, inst.mdbHost, cmd)
	logCmd(fmt.Sprintf("root@%s '%s'", inst.mdbHost, cmd))
	// Use stdout only — the SSH banner goes to stderr and we don't want it mixed in
	c := exec.Command("bash", "-c", sshCmd)
	out, err := c.Output()
	return string(out), err
}

func (inst *Installer) mdbSCP(localPath, remotePath string) error {
	scpCmd := fmt.Sprintf("sshpass -p '%s' scp -O %s '%s' root@%s:'%s'",
		inst.mdbPassword, mdbSSHOpts, localPath, inst.mdbHost, remotePath)
	logCmd(fmt.Sprintf("scp %s -> root@%s:%s", filepath.Base(localPath), inst.mdbHost, remotePath))
	_, err := runShell(scpCmd)
	return err
}

func (inst *Installer) getMDBInfo() (map[string]string, error) {
	info := map[string]string{"version": "Unknown"}

	out, err := inst.mdbSSH("cat /etc/os-release 2>/dev/null")
	if err != nil {
		return nil, fmt.Errorf("SSH to MDB failed: %w", err)
	}

	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "VERSION_ID=") {
			v := strings.TrimPrefix(line, "VERSION_ID=")
			v = strings.Trim(v, `"`)
			info["version"] = v
		}
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			v := strings.TrimPrefix(line, "PRETTY_NAME=")
			info["pretty_name"] = strings.Trim(v, `"`)
		}
	}

	// Get serial number from OTP fuses
	if cfg0, err := inst.mdbSSH("cat /sys/fsl_otp/HW_OCOTP_CFG0 2>/dev/null"); err == nil {
		cfg0 = strings.TrimSpace(cfg0)
		cfg1, _ := inst.mdbSSH("cat /sys/fsl_otp/HW_OCOTP_CFG1 2>/dev/null")
		cfg1 = strings.TrimSpace(cfg1)
		if cfg0 != "" || cfg1 != "" {
			s0 := strings.TrimPrefix(strings.TrimPrefix(cfg0, "0x"), "0X")
			s1 := strings.TrimPrefix(strings.TrimPrefix(cfg1, "0x"), "0X")
			info["serial"] = strings.ToLower(s0 + s1)
		}
	}

	return info, nil
}

func (inst *Installer) configureBootloader() error {
	// Check if the MDB has its own fw_setenv (LibreScoot has one at /usr/bin/fw_setenv
	// with /etc/fw_env.config pointing to the correct U-Boot env offsets)
	var fwSetenvCmd string
	if out, err := inst.mdbSSH("which fw_setenv 2>/dev/null && test -f /etc/fw_env.config && echo OK"); err == nil && strings.Contains(out, "OK") {
		fwSetenvCmd = "fw_setenv"
		logInfo("Using MDB's native fw_setenv with /etc/fw_env.config")
	} else {
		// Stock scooterOS: upload our bundled fw_setenv with stock env layout
		tmpDir, err := os.MkdirTemp("", "librescoot-install-*")
		if err != nil {
			return err
		}
		defer os.RemoveAll(tmpDir)

		fwSetenvPath := filepath.Join(tmpDir, "fw_setenv")
		fwConfigPath := filepath.Join(tmpDir, "fw_env.config")

		if err := os.WriteFile(fwSetenvPath, fwSetenvBin, 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(fwConfigPath, fwEnvConfig, 0o644); err != nil {
			return err
		}

		if err := inst.mdbSCP(fwSetenvPath, "/tmp/fw_setenv"); err != nil {
			return fmt.Errorf("uploading fw_setenv: %w", err)
		}
		if err := inst.mdbSCP(fwConfigPath, "/tmp/fw_env.config"); err != nil {
			return fmt.Errorf("uploading fw_env.config: %w", err)
		}
		inst.mdbSSH("chmod +x /tmp/fw_setenv")
		fwSetenvCmd = "/tmp/fw_setenv -c /tmp/fw_env.config"
		logInfo("Using bundled fw_setenv with stock env layout")
	}

	// Set bootcmd to enter USB mass storage mode — try with fuse programming first (legacy boards)
	fullBootcmd := fmt.Sprintf(`%s bootcmd "fuse prog -y 0 5 0x00002860; fuse prog -y 0 6 0x00000010; ums 0 mmc 1"`, fwSetenvCmd)
	if _, err := inst.mdbSSH(fullBootcmd); err != nil {
		logWarn("Full bootcmd failed, trying fallback: %v", err)
		fallbackBootcmd := fmt.Sprintf(`%s bootcmd "ums 0 mmc 1"`, fwSetenvCmd)
		if _, err := inst.mdbSSH(fallbackBootcmd); err != nil {
			return fmt.Errorf("setting bootcmd: %w", err)
		}
	}

	// Set boot delay to 0
	if _, err := inst.mdbSSH(fmt.Sprintf(`%s bootdelay 0`, fwSetenvCmd)); err != nil {
		return fmt.Errorf("setting bootdelay: %w", err)
	}

	logInfo("Bootloader configured for USB mass storage mode")
	return nil
}

func (inst *Installer) rebootMDB() error {
	// Try multiple reboot commands — stock scooterOS may not have all of them in PATH
	cmds := []string{"reboot", "/sbin/reboot", "busybox reboot", "shutdown -r now"}
	for _, cmd := range cmds {
		_, err := inst.mdbSSH(cmd)
		if err == nil {
			logInfo("MDB is rebooting...")
			return nil
		}
		errStr := strings.ToLower(err.Error())
		// Connection drop or exit 255 means the reboot worked
		if strings.Contains(errStr, "closed") ||
			strings.Contains(errStr, "reset") ||
			strings.Contains(errStr, "broken pipe") ||
			strings.Contains(errStr, "exit status 255") {
			logInfo("MDB is rebooting...")
			return nil
		}
		// exit status 127 = command not found, try next
		if strings.Contains(errStr, "exit status 127") {
			continue
		}
		// Some other error — still try next command
		logWarn("reboot command %q failed: %v", cmd, err)
	}
	return fmt.Errorf("all reboot commands failed")
}

func (inst *Installer) waitForMassStorage(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	logInfo("Waiting up to %s for USB mass storage (0525:a4a5)...", timeout)

	for time.Now().Before(deadline) {
		out, err := run("lsusb", "-d", usbVID+":"+pidUMS)
		if err == nil && strings.TrimSpace(out) != "" {
			logInfo("Mass storage detected: %s", strings.TrimSpace(out))
			// Give the kernel a moment to set up the block device
			time.Sleep(3 * time.Second)
			return nil
		}
		time.Sleep(2 * time.Second)
	}

	return fmt.Errorf("timed out waiting for USB mass storage device")
}

func (inst *Installer) findBlockDevice() (string, error) {
	// Look for USB transport block devices
	out, err := run("lsblk", "-d", "-n", "-o", "NAME,TRAN,SIZE")
	if err != nil {
		return "", err
	}

	for _, line := range strings.Split(out, "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[1] == "usb" {
			dev := "/dev/" + fields[0]
			size := ""
			if len(fields) >= 3 {
				size = fields[2]
			}
			logInfo("Found USB block device: %s (%s)", dev, size)

			// Safety: don't flash anything that looks like a system disk
			if fields[0] == "sda" {
				logWarn("%s might be a system disk, verifying...", dev)
				if isSystemDisk(dev) {
					continue
				}
			}
			return dev, nil
		}
	}

	return "", fmt.Errorf("no USB block device found — is the MDB in mass storage mode?")
}

func isSystemDisk(dev string) bool {
	out, _ := run("mount")
	return strings.Contains(out, dev)
}

func (inst *Installer) flashImage(devicePath string) error {
	// Unmount any existing partitions
	// Use -n -l (list, no tree) to avoid tree-drawing characters like └─
	out, _ := run("lsblk", "-n", "-l", "-o", "NAME", devicePath)
	devBase := filepath.Base(devicePath)
	for _, line := range strings.Split(out, "\n") {
		name := strings.TrimSpace(line)
		if name == "" || name == devBase {
			continue
		}
		part := "/dev/" + name
		logInfo("Unmounting %s", part)
		runSudo("umount", part)
	}

	// Build dd command
	var cmd string
	if strings.HasSuffix(inst.imagePath, ".gz") {
		cmd = fmt.Sprintf("gunzip -c '%s' | sudo dd of='%s' bs=4M iflag=fullblock oflag=direct status=progress",
			inst.imagePath, devicePath)
	} else {
		cmd = fmt.Sprintf("sudo dd if='%s' of='%s' bs=4M iflag=fullblock oflag=direct status=progress",
			inst.imagePath, devicePath)
	}

	logInfo("Writing image...")
	logCmd(cmd)

	c := exec.Command("bash", "-c", cmd)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		return fmt.Errorf("dd failed: %w", err)
	}

	logInfo("Syncing...")
	runShell("sync")

	logInfo("Flash complete")
	return nil
}

// waitForBoot waits for the MDB to boot into LibreScoot after flashing.
// First waits for the RNDIS USB device to reappear, configures the network
// interface, then waits for stable ping (10 consecutive successes).
func (inst *Installer) waitForBoot(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	// Phase 1: wait for RNDIS USB device
	logInfo("Waiting for RNDIS device (0525:a4a2)...")
	for time.Now().Before(deadline) {
		out, err := run("lsusb", "-d", usbVID+":"+pidRNDIS)
		if err == nil && strings.TrimSpace(out) != "" {
			logInfo("RNDIS device detected")
			break
		}
		time.Sleep(3 * time.Second)
	}
	if time.Now().After(deadline) {
		return fmt.Errorf("timed out waiting for RNDIS device")
	}

	// Phase 2: configure network interface
	time.Sleep(2 * time.Second)
	if err := inst.ensureNetworkInterface(); err != nil {
		logWarn("Network config: %v", err)
	}

	// Phase 3: wait for stable ping (10 consecutive successes, 1s apart)
	logInfo("Waiting for stable network (10 consecutive pings)...")
	consecutive := 0
	required := 10
	for time.Now().Before(deadline) {
		_, err := run("ping", "-c", "1", "-W", "2", inst.mdbHost)
		if err == nil {
			consecutive++
			if consecutive >= required {
				logInfo("MDB is up and stable")
				return nil
			}
		} else {
			if consecutive > 0 {
				logInfo("Ping dropped after %d, restarting count...", consecutive)
			}
			consecutive = 0
		}
		time.Sleep(1 * time.Second)
	}
	return fmt.Errorf("timed out waiting for stable connection (got %d/%d consecutive pings)", consecutive, required)
}

// run executes a command and returns its combined output.
func run(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).CombinedOutput()
	return string(out), err
}

// runSudo executes a command with sudo.
func runSudo(name string, args ...string) (string, error) {
	sudoArgs := append([]string{name}, args...)
	return run("sudo", sudoArgs...)
}

// runShell executes a shell command string via bash.
func runShell(cmd string) (string, error) {
	out, err := exec.Command("bash", "-c", cmd).CombinedOutput()
	return string(out), err
}
