package main

import (
	"fmt"
	"strings"
	"time"
)

// runStation watches for an MDB to appear on USB and runs the appropriate
// phase. After each completion it prompts the operator to swap to the next
// scooter. The detection is host-side via lsusb (works on Linux and macOS
// the same; Windows needs different polling).
func (inst *Installer) runStation() error {
	logStep("Station mode — connect a scooter to begin.")
	logInfo("Ctrl-C to exit. The CLI runs the next applicable phase whenever an MDB shows up.")

	lastFingerprint := ""
	for {
		fp, present := inst.detectAnyScooter()
		if !present {
			time.Sleep(3 * time.Second)
			continue
		}
		if fp == lastFingerprint {
			// Same scooter we just finished; tell the operator to swap.
			logInfo("Same scooter still connected — swap when ready (Ctrl-C to exit).")
			time.Sleep(5 * time.Second)
			continue
		}

		logStep("Scooter detected (%s) — running auto phase.", fp)
		if err := inst.runAuto(); err != nil {
			logWarn("Auto phase failed: %v", err)
			// Don't update fingerprint; wait for the operator to swap or fix.
			time.Sleep(10 * time.Second)
			continue
		}
		lastFingerprint = fp
		logStep("Done with %s — disconnect and connect the next scooter.", fp)
	}
}

// runAuto detects the current phase and runs the next applicable one.
// Returns when a phase boundary is hit (handoff or finish).
func (inst *Installer) runAuto() error {
	if err := inst.detectMDB(); err != nil {
		// MDB unreachable; this is also the state where phase1 starts —
		// but we need a baseline working SSH for phase1. The CLI assumes
		// stock SSH access already exists.
		return fmt.Errorf("MDB unreachable for auto detection: %w", err)
	}

	st, err := inst.detectPhase()
	if err != nil {
		return fmt.Errorf("phase detection failed: %w", err)
	}
	logInfo("Detected phase: %s", st.Phase)

	switch st.Phase {
	case PhaseFresh, PhaseMDBPrepped:
		return inst.runPhase1()
	case PhaseMDBFlashed:
		// MDB in UMS or rebooting; just wait it out and then keep going.
		return inst.runPhase1()
	case PhaseMDBBooted, PhaseDBCStaged:
		return inst.runPhase2()
	case PhaseTrampolineRun:
		if err := inst.monitorTrampoline(); err != nil {
			return err
		}
		return inst.runPhase3()
	case PhaseTrampolineOK:
		return inst.runPhase3()
	case PhaseTrampolineErr:
		return fmt.Errorf("trampoline previously failed; manual intervention needed")
	case PhaseFinished:
		logInfo("This scooter is finished. Disconnect to move on.")
		return nil
	default:
		return fmt.Errorf("unknown phase: %s", st.Phase)
	}
}

// detectAnyScooter returns a fingerprint identifying the connected scooter
// (basically lsusb's iSerialNumber line, or the OS-side serial we read
// over SSH). The fingerprint is opaque — it just needs to change when the
// operator swaps to a different unit.
func (inst *Installer) detectAnyScooter() (string, bool) {
	// Either RNDIS (normal) or UMS (post-flash) USB IDs are valid signals.
	for _, pid := range []string{pidRNDIS, pidUMS} {
		out, _ := run("lsusb", "-v", "-d", usbVID+":"+pid)
		if strings.TrimSpace(out) == "" {
			continue
		}
		// Try to extract iSerial; on stock and Librescoot images this is
		// often a fixed string like "0123456789ABCDEF". If not, fall back
		// to ping check + any non-empty output.
		for _, line := range strings.Split(out, "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "iSerial") {
				fields := strings.Fields(line)
				if len(fields) >= 3 {
					return strings.Join(fields[2:], " "), true
				}
			}
		}
		// No iSerial → just say "present" with a static token. Operator
		// must disconnect/reconnect to advance.
		return "usb:" + pid, true
	}
	return "", false
}
