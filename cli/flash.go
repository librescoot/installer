package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func (inst *Installer) waitForMassStorage(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	logInfo("Waiting up to %s for USB mass storage (%s:%s)...", timeout, usbVID, pidUMS)

	for time.Now().Before(deadline) {
		out, err := run("lsusb", "-d", usbVID+":"+pidUMS)
		if err == nil && strings.TrimSpace(out) != "" {
			logInfo("Mass storage detected: %s", strings.TrimSpace(out))
			time.Sleep(3 * time.Second) // let kernel finish setting up the block device
			return nil
		}
		time.Sleep(2 * time.Second)
	}

	return fmt.Errorf("timed out waiting for USB mass storage device")
}

func (inst *Installer) findBlockDevice() (string, error) {
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

// flashImage writes the firmware to the block device. Prefers bmap-writer
// if both a bmap file and the bmap-writer binary are available, falls back
// to gunzip|dd with direct I/O otherwise.
func (inst *Installer) flashImage(devicePath string) error {
	// Unmount any auto-mounted partitions on this device.
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

	hasBmap := inst.bmapPath != ""
	if !hasBmap {
		bmapCandidate := strings.TrimSuffix(inst.imagePath, ".gz") + ".bmap"
		if _, err := os.Stat(bmapCandidate); err == nil {
			inst.bmapPath = bmapCandidate
			hasBmap = true
		}
	}

	_, bmapWriterErr := exec.LookPath("bmap-writer")
	hasBmapWriter := bmapWriterErr == nil

	var cmd string
	if hasBmap && hasBmapWriter {
		logInfo("Using bmap-writer (faster, block-level checksums)")
		cmd = fmt.Sprintf("sudo bmap-writer --bmap %s %s %s",
			shellQuote(inst.bmapPath), shellQuote(inst.imagePath), shellQuote(devicePath))
	} else {
		if hasBmap && !hasBmapWriter {
			logWarn("bmap file available but bmap-writer not found, falling back to dd")
		}
		if strings.HasSuffix(inst.imagePath, ".gz") {
			cmd = fmt.Sprintf("gunzip -c %s | sudo dd of=%s bs=4M iflag=fullblock oflag=direct status=progress",
				shellQuote(inst.imagePath), shellQuote(devicePath))
		} else {
			cmd = fmt.Sprintf("sudo dd if=%s of=%s bs=4M iflag=fullblock oflag=direct status=progress",
				shellQuote(inst.imagePath), shellQuote(devicePath))
		}
	}

	logInfo("Writing image...")
	logCmd(cmd)

	c := exec.Command("bash", "-c", cmd)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		return fmt.Errorf("flash failed: %w", err)
	}

	logInfo("Syncing...")
	runShell("sync")

	logInfo("Flash complete")
	return nil
}
