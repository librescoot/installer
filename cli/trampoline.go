package main

import (
	_ "embed"
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

//go:embed assets/trampoline.sh.template
var trampolineTemplate string

//go:embed assets/librescoot-flasher-linux-arm
var dbcFlasherARM []byte

//go:embed assets/fw_setenv-dbc
var fwSetenvDBCBin []byte

//go:embed assets/fw_env-dbc.config
var fwEnvDBCConfig []byte

// stageDBCArtifacts uploads everything the trampoline needs onto the MDB.
// All paths under /data/installer/ so the cleanup at finish nukes them with
// one rm -rf.
func (inst *Installer) stageDBCArtifacts(st *State) error {
	logStep("Staging DBC artifacts under /data/installer...")

	// Mkdir the staging area. Plus a per-tool subdir for the DBC env tools.
	if _, err := inst.mdbSSH("mkdir -p /data/installer /data/installer/fwtools/stock-dbc"); err != nil {
		return fmt.Errorf("mkdir installer dir: %w", err)
	}

	// Upload the ARM flasher binary the trampoline will use on the MDB to
	// drive the DBC's UMS-mode block device.
	logInfo("Uploading librescoot-flasher (ARM)...")
	if err := inst.mdbWriteFile("/data/installer/librescoot-flasher", dbcFlasherARM, "0755"); err != nil {
		return fmt.Errorf("upload librescoot-flasher: %w", err)
	}

	// fw_setenv + config for the DBC U-Boot env. Different offsets than MDB.
	if err := inst.mdbWriteFile("/data/installer/fwtools/stock-dbc/fw_setenv", fwSetenvDBCBin, "0755"); err != nil {
		return fmt.Errorf("upload fw_setenv-dbc: %w", err)
	}
	if err := inst.mdbWriteFile("/data/installer/fwtools/stock-dbc/fw_env.config", fwEnvDBCConfig, "0644"); err != nil {
		return fmt.Errorf("upload fw_env-dbc.config: %w", err)
	}

	// Upload the DBC image (and bmap if present). SCP is cheaper than base64
	// for files this large.
	dbcImageBase := filepath.Base(inst.dbcImagePath)
	logInfo("Uploading DBC image %s (this is the slow bit)...", dbcImageBase)
	if err := inst.mdbSCP(inst.dbcImagePath, "/data/installer/"+dbcImageBase); err != nil {
		return fmt.Errorf("uploading DBC image: %w", err)
	}
	st.DBCImage = dbcImageBase

	if inst.dbcBmapPath != "" {
		bmapBase := filepath.Base(inst.dbcBmapPath)
		logInfo("Uploading DBC bmap %s...", bmapBase)
		if err := inst.mdbSCP(inst.dbcBmapPath, "/data/installer/"+bmapBase); err != nil {
			logWarn("DBC bmap upload failed (will fall back to dd): %v", err)
		}
	}

	// Optional tile uploads. These end up at /data/installer/<basename> and
	// the onboot.sh emitted by the trampoline curls them across to the DBC.
	if inst.osmTilesPath != "" {
		base := filepath.Base(inst.osmTilesPath)
		logInfo("Uploading OSM tiles %s...", base)
		if err := inst.mdbSCP(inst.osmTilesPath, "/data/installer/"+base); err != nil {
			return fmt.Errorf("uploading OSM tiles: %w", err)
		}
		st.OSMTiles = base
	}
	if inst.valTilesPath != "" {
		base := filepath.Base(inst.valTilesPath)
		logInfo("Uploading Valhalla tiles %s...", base)
		if err := inst.mdbSCP(inst.valTilesPath, "/data/installer/"+base); err != nil {
			return fmt.Errorf("uploading Valhalla tiles: %w", err)
		}
		st.ValhallaTar = base
	}

	return nil
}

// kickOffTrampoline renders the trampoline script with the staged paths and
// starts it via nohup. After this returns, the script is detached on the
// MDB — the host can disconnect.
func (inst *Installer) kickOffTrampoline(st *State) error {
	if st.DBCImage == "" {
		return fmt.Errorf("no DBC image staged in state.json")
	}

	installTiles := "0"
	if st.OSMTiles != "" || st.ValhallaTar != "" {
		installTiles = "1"
	}

	script := trampolineTemplate
	script = strings.ReplaceAll(script, "{{DBC_IMAGE_PATH}}", "/data/installer/"+st.DBCImage)
	script = strings.ReplaceAll(script, "{{INSTALL_TILES}}", installTiles)
	script = strings.ReplaceAll(script, "{{OSM_TILES_FILE}}", st.OSMTiles)
	script = strings.ReplaceAll(script, "{{VALHALLA_TILES_FILE}}", st.ValhallaTar)

	if err := inst.mdbWriteFile("/data/installer/trampoline.sh", []byte(script), "0755"); err != nil {
		return fmt.Errorf("uploading trampoline.sh: %w", err)
	}

	// Truncate any previous status file so monitor doesn't pick up stale state.
	inst.mdbSSH("rm -f /data/installer/trampoline-status /data/installer/trampoline.log /data/installer/trampoline-stdout.log")

	logStep("Starting trampoline detached on MDB...")
	if err := inst.mdbSSHDetached("/data/installer/trampoline.sh > /data/installer/trampoline-stdout.log 2>&1"); err != nil {
		return fmt.Errorf("starting trampoline: %w", err)
	}

	// Confirm the trampoline process is actually running.
	time.Sleep(2 * time.Second)
	if out, _ := inst.mdbSSHOnce("pgrep -fa trampoline.sh"); strings.TrimSpace(out) == "" {
		logWarn("trampoline.sh not detected via pgrep — check /data/installer/trampoline-stdout.log on MDB")
	}
	return nil
}

// monitorTrampoline tails the status file until success or failure. Used
// by --wait and station mode; phase2 without --wait returns earlier.
func (inst *Installer) monitorTrampoline() error {
	logStep("Monitoring trampoline (status file: /data/installer/trampoline-status)...")

	lastLogSize := int64(0)
	deadline := time.Now().Add(20 * time.Minute)
	for time.Now().Before(deadline) {
		// Tail any new log lines since last poll. journalctl mirrors here too.
		logTail, _ := inst.mdbSSHOnce(fmt.Sprintf(
			"awk -v skip=%d 'NR>skip' /data/installer/trampoline.log 2>/dev/null | tail -20",
			lastLogSize))
		if strings.TrimSpace(logTail) != "" {
			for _, line := range strings.Split(logTail, "\n") {
				if line = strings.TrimRight(line, "\r"); line != "" {
					logInfo("trampoline | %s", line)
				}
			}
			cnt, _ := inst.mdbSSHOnce("wc -l < /data/installer/trampoline.log 2>/dev/null")
			if v := parseInt64(strings.TrimSpace(cnt)); v > 0 {
				lastLogSize = v
			}
		}

		out, _ := inst.mdbSSHOnce("test -f /data/installer/trampoline-status && cat /data/installer/trampoline-status | head -1")
		switch h := strings.TrimSpace(strings.SplitN(out, "\n", 2)[0]); h {
		case "success":
			logStep("Trampoline reported success.")
			return nil
		case "":
			// still running
		default:
			if strings.HasPrefix(h, "error") {
				return fmt.Errorf("trampoline reported failure: %s", h)
			}
		}

		time.Sleep(5 * time.Second)
	}
	return fmt.Errorf("trampoline did not complete within 20 minutes")
}

func parseInt64(s string) int64 {
	var v int64
	for _, c := range s {
		if c < '0' || c > '9' {
			return v
		}
		v = v*10 + int64(c-'0')
	}
	return v
}
