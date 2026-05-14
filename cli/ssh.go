package main

import (
	"encoding/base64"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const mdbSSHOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3"

// mdbSSH runs a command on the MDB via SSH. It retries once on
// disconnect-class failures (USB cable hiccup, connection reset, etc.).
// Use mdbSSHOnce for a single, no-retry attempt.
func (inst *Installer) mdbSSH(cmd string) (string, error) {
	out, err := inst.mdbSSHOnce(cmd)
	if err == nil {
		return out, nil
	}
	if !isDisconnectErr(err) {
		return out, err
	}
	logWarn("SSH disconnected; reconnecting in 3s...")
	time.Sleep(3 * time.Second)
	return inst.mdbSSHOnce(cmd)
}

func (inst *Installer) mdbSSHOnce(cmd string) (string, error) {
	sshCmd := fmt.Sprintf("sshpass -p %s ssh %s root@%s %s",
		shellQuote(inst.mdbPassword), mdbSSHOpts, inst.mdbHost, shellQuote(cmd))
	logCmd(fmt.Sprintf("root@%s '%s'", inst.mdbHost, abbreviate(cmd, 120)))
	c := exec.Command("bash", "-c", sshCmd)
	out, err := c.Output()
	return string(out), err
}

// mdbSSHDetached fires a command on the MDB and disconnects immediately.
// Used for actions where SSH will lose the connection (reboot, USB gadget teardown).
func (inst *Installer) mdbSSHDetached(cmd string) error {
	wrapped := fmt.Sprintf("nohup sh -c %s >/dev/null 2>&1 </dev/null &", shellQuote(cmd))
	_, err := inst.mdbSSHOnce(wrapped)
	return err
}

func (inst *Installer) mdbSCP(localPath, remotePath string) error {
	scpCmd := fmt.Sprintf("sshpass -p %s scp -O %s %s root@%s:%s",
		shellQuote(inst.mdbPassword), mdbSSHOpts,
		shellQuote(localPath), inst.mdbHost, shellQuote(remotePath))
	logCmd(fmt.Sprintf("scp %s -> root@%s:%s", filepath.Base(localPath), inst.mdbHost, remotePath))
	_, err := runShell(scpCmd)
	return err
}

// mdbWriteFile uploads a chunk of bytes to a remote path via base64-decoded SSH.
// Useful for small files where SCP setup overhead isn't worth it.
func (inst *Installer) mdbWriteFile(remotePath string, data []byte, mode string) error {
	enc := base64.StdEncoding.EncodeToString(data)
	cmd := fmt.Sprintf("mkdir -p %s && echo %s | base64 -d > %s && chmod %s %s",
		shellQuote(filepath.Dir(remotePath)),
		enc, shellQuote(remotePath), mode, shellQuote(remotePath))
	_, err := inst.mdbSSH(cmd)
	return err
}

// mdbReadFile reads a small file off the MDB, returning empty string if missing.
func (inst *Installer) mdbReadFile(remotePath string) (string, error) {
	return inst.mdbSSH(fmt.Sprintf("cat %s 2>/dev/null", shellQuote(remotePath)))
}

// mdbWaitForSSH polls MDB ping + SSH handshake until both succeed or timeout.
func (inst *Installer) mdbWaitForSSH(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if _, err := run("ping", "-c", "1", "-W", "2", inst.mdbHost); err == nil {
			if _, err := inst.mdbSSHOnce("true"); err == nil {
				return nil
			}
		}
		time.Sleep(2 * time.Second)
	}
	return fmt.Errorf("timed out waiting for SSH to %s", inst.mdbHost)
}

func isDisconnectErr(err error) bool {
	if err == nil {
		return false
	}
	s := strings.ToLower(err.Error())
	return strings.Contains(s, "closed by") ||
		strings.Contains(s, "connection reset") ||
		strings.Contains(s, "broken pipe") ||
		strings.Contains(s, "no route to host") ||
		strings.Contains(s, "connection refused") ||
		strings.Contains(s, "connection timed out") ||
		strings.Contains(s, "host is down") ||
		strings.Contains(s, "exit status 255")
}

// shellQuote wraps a string in single quotes for safe shell interpolation.
// Embedded single quotes are escaped via the '\'' trick.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func abbreviate(s string, max int) string {
	s = strings.ReplaceAll(s, "\n", " ")
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
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
