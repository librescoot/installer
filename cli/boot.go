package main

import (
	"fmt"
	"strings"
	"time"
)

// waitForBoot waits for the MDB to come back up after the UMS-flash power
// cycle. Polls RNDIS USB ID first, then re-configures the host iface
// (NetworkManager doesn't carry our /24 over an interface flap), then
// waits for 10 consecutive successful pings.
func (inst *Installer) waitForBoot(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	logInfo("Waiting for RNDIS device (%s:%s)...", usbVID, pidRNDIS)
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

	// The iface name changes across a flap (predictable names tied to MAC).
	// Re-detect and re-add the IP — best-effort.
	time.Sleep(2 * time.Second)
	if err := inst.ensureNetworkInterface(); err != nil {
		logWarn("Network config: %v", err)
	}

	logInfo("Waiting for stable network (10 consecutive pings)...")
	consecutive := 0
	const required = 10
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
