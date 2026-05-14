package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// detectMDB checks that the MDB is reachable in RNDIS ethernet mode.
// Best-effort RNDIS check followed by ping; configures the host network
// interface if NetworkManager hasn't already.
func (inst *Installer) detectMDB() error {
	out, err := run("lsusb", "-d", usbVID+":"+pidRNDIS)
	if err == nil && strings.TrimSpace(out) != "" {
		logInfo("Found RNDIS device: %s", strings.TrimSpace(out))
	} else {
		logWarn("RNDIS USB device not found in lsusb, checking network anyway...")
	}

	if err := inst.ensureNetworkInterface(); err != nil {
		logWarn("Network config: %v", err)
	}

	if _, err := run("ping", "-c", "1", "-W", "3", inst.mdbHost); err != nil {
		return fmt.Errorf("MDB at %s is not reachable (ping failed)", inst.mdbHost)
	}
	logInfo("MDB reachable at %s", inst.mdbHost)
	return nil
}

func (inst *Installer) ensureNetworkInterface() error {
	if _, err := run("ping", "-c", "1", "-W", "2", inst.mdbHost); err == nil {
		return nil
	}

	// Async cdc_ether bind can take a few seconds — poll for the interface
	// instead of giving up on the first read.
	var iface string
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if found, err := inst.findRNDISInterface(); err == nil {
			iface = found
			break
		}
		time.Sleep(500 * time.Millisecond)
	}
	if iface == "" {
		return fmt.Errorf("no RNDIS network interface appeared within 10s")
	}
	logInfo("Found interface: %s", iface)

	runSudo("ip", "link", "set", iface, "up")
	out, err := runSudo("ip", "addr", "add", "192.168.7.50/24", "dev", iface)
	if err != nil && !strings.Contains(out+err.Error(), "File exists") {
		return fmt.Errorf("failed to configure %s: %w (root needed?)", iface, err)
	}

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
		if iface == "usb0" || strings.HasPrefix(iface, "enx") || strings.HasPrefix(iface, "enp") {
			driverPath := fmt.Sprintf("/sys/class/net/%s/device/driver", iface)
			if target, err := os.Readlink(driverPath); err == nil {
				driver := filepath.Base(target)
				if driver == "cdc_ether" || driver == "rndis_host" || driver == "cdc_subset" {
					return iface, nil
				}
			}
			// Accept enx* even without driver readlink — predictable name pattern is enough.
			if strings.HasPrefix(iface, "enx") {
				return iface, nil
			}
		}
	}
	return "", fmt.Errorf("no RNDIS network interface found")
}

// getMDBInfo reads /etc/os-release + OTP fuses to identify the MDB.
// Serial is composed as CFG1:CFG0 (low word last) to agree with U-Boot,
// kernel soc_id and radio-gaga.
func (inst *Installer) getMDBInfo() (map[string]string, error) {
	info := map[string]string{"version": "Unknown"}

	out, err := inst.mdbSSH("cat /etc/os-release 2>/dev/null")
	if err != nil {
		return nil, fmt.Errorf("SSH to MDB failed: %w", err)
	}

	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "VERSION_ID=") {
			info["version"] = strings.Trim(strings.TrimPrefix(line, "VERSION_ID="), `"`)
		}
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			info["pretty_name"] = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), `"`)
		}
	}

	if cfg0, err := inst.mdbSSH("cat /sys/fsl_otp/HW_OCOTP_CFG0 2>/dev/null"); err == nil {
		cfg0 = strings.TrimSpace(cfg0)
		cfg1, _ := inst.mdbSSH("cat /sys/fsl_otp/HW_OCOTP_CFG1 2>/dev/null")
		cfg1 = strings.TrimSpace(cfg1)
		if cfg0 != "" || cfg1 != "" {
			s0 := strings.TrimPrefix(strings.TrimPrefix(cfg0, "0x"), "0X")
			s1 := strings.TrimPrefix(strings.TrimPrefix(cfg1, "0x"), "0X")
			// CFG1:CFG0 — radio-gaga, kernel soc_id, U-Boot all use this order.
			info["serial"] = strings.ToLower(s1 + s0)
		}
	}

	return info, nil
}
