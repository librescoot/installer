package main

import (
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

//go:embed assets/fw_setenv
var fwSetenvBin []byte

//go:embed assets/fw_env.config
var fwEnvConfig []byte

// configureBootloader sets bootcmd to enter U-Boot UMS mode. Uses MDB's
// native fw_setenv on Librescoot re-flashes; falls back to a bundled
// statically linked binary on stock images.
func (inst *Installer) configureBootloader() error {
	var fwSetenvCmd string
	if out, err := inst.mdbSSH("which fw_setenv 2>/dev/null && test -f /etc/fw_env.config && echo OK"); err == nil && strings.Contains(out, "OK") {
		fwSetenvCmd = "fw_setenv"
		logInfo("Using MDB's native fw_setenv with /etc/fw_env.config")
	} else {
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

	// Legacy boards need OTP fuses programmed (boot fuse + bootloader offset).
	// Fall back to plain UMS bootcmd if fuse prog isn't available on this image.
	fullBootcmd := fmt.Sprintf(`%s bootcmd "fuse prog -y 0 5 0x00002860; fuse prog -y 0 6 0x00000010; ums 0 mmc 1"`, fwSetenvCmd)
	if _, err := inst.mdbSSH(fullBootcmd); err != nil {
		logWarn("Full bootcmd failed, trying fallback: %v", err)
		fallback := fmt.Sprintf(`%s bootcmd "ums 0 mmc 1"`, fwSetenvCmd)
		if _, err := inst.mdbSSH(fallback); err != nil {
			return fmt.Errorf("setting bootcmd: %w", err)
		}
	}

	if _, err := inst.mdbSSH(fmt.Sprintf(`%s bootdelay 0`, fwSetenvCmd)); err != nil {
		return fmt.Errorf("setting bootdelay: %w", err)
	}

	logInfo("Bootloader configured for USB mass storage mode")
	return nil
}

func (inst *Installer) rebootMDB() error {
	// Several reboot paths exist; stock scooterOS doesn't have all of them in PATH.
	cmds := []string{"reboot", "/sbin/reboot", "busybox reboot", "shutdown -r now"}
	for _, cmd := range cmds {
		_, err := inst.mdbSSH(cmd)
		if err == nil {
			logInfo("MDB is rebooting...")
			return nil
		}
		// Connection drop / exit 255 = reboot took the SSH session down.
		if isDisconnectErr(err) {
			logInfo("MDB is rebooting...")
			return nil
		}
		errStr := strings.ToLower(err.Error())
		if strings.Contains(errStr, "exit status 127") {
			continue
		}
		logWarn("reboot command %q failed: %v", cmd, err)
	}
	return fmt.Errorf("all reboot commands failed")
}
