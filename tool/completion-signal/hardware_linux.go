package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

type vehicleOwner struct {
	pid   int
	start string
}

func observeOwner(invocation string) (*vehicleOwner, error) {
	output, err := exec.Command("systemctl", "show", "-p", "InvocationID", "-p", "MainPID", "librescoot-vehicle").Output()
	if err != nil {
		return nil, err
	}
	fields := map[string]string{}
	for _, line := range strings.Split(string(output), "\n") {
		if key, value, ok := strings.Cut(line, "="); ok {
			fields[key] = value
		}
	}
	if fields["InvocationID"] != invocation {
		return nil, fmt.Errorf("vehicle-service invocation changed")
	}
	pid, err := strconv.Atoi(fields["MainPID"])
	if err != nil || pid <= 0 {
		return nil, fmt.Errorf("vehicle-service is not running")
	}
	o := &vehicleOwner{pid: pid}
	o.start, err = o.identity()
	return o, err
}

func (o *vehicleOwner) identity() (string, error) {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", o.pid))
	if err != nil {
		return "", err
	}
	// comm may contain spaces and parentheses; starttime is field 22.
	end := strings.LastIndexByte(string(data), ')')
	if end < 0 {
		return "", fmt.Errorf("invalid process identity")
	}
	fields := strings.Fields(string(data[end+1:]))
	if len(fields) <= 19 {
		return "", fmt.Errorf("truncated process identity")
	}
	return fields[19], nil
}
func (o *vehicleOwner) Current() bool {
	start, err := o.identity()
	return err == nil && start == o.start
}

type nativeLights struct {
	files    map[int]*os.File
	channels []int
	led      *os.File
	trace    *os.File
	started  time.Time
}

func openLights(channels []int, dashboardLED bool, trace string) (*nativeLights, error) {
	l := &nativeLights{files: map[int]*os.File{}, channels: channels, started: time.Now()}
	for _, channel := range channels {
		file, err := os.OpenFile(fmt.Sprintf("/dev/pwm_led%d", channel), os.O_RDWR, 0)
		if err != nil {
			l.Close()
			return nil, err
		}
		l.files[channel] = file
	}
	if dashboardLED {
		file, err := os.OpenFile("/dev/i2c-2", os.O_RDWR, 0)
		if err != nil {
			l.Close()
			return nil, err
		}
		l.led = file
		if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, file.Fd(), 0x0706, 0x30); errno != 0 {
			l.Close()
			return nil, errno
		}
	}
	if trace != "" {
		file, err := os.OpenFile(trace, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0600)
		if err != nil {
			l.Close()
			return nil, err
		}
		l.trace = file
	}
	return l, nil
}

func duty(file *os.File) (uint32, error) {
	// GET_DUTY encodes ushort but the driver copies a uint into the buffer.
	var value uint32
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, file.Fd(), 0x8002754B, uintptr(unsafe.Pointer(&value)))
	if errno != 0 {
		return 0, errno
	}
	return value, nil
}
func (l *nativeLights) Snapshot() (map[int]uint32, error) {
	values := map[int]uint32{}
	for _, channel := range l.channels {
		value, err := duty(l.files[channel])
		if err != nil {
			return nil, err
		}
		values[channel] = value
	}
	return values, nil
}
func (l *nativeLights) Restore(values map[int]uint32) error {
	for _, channel := range l.channels {
		value, ok := values[channel]
		if !ok || value > 65535 {
			return fmt.Errorf("invalid saved lamp duty")
		}
		if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, l.files[channel].Fd(), 0x754A, uintptr(value)); errno != 0 {
			return errno
		}
		if l.trace != nil {
			// Diagnostic readback waits for SDMA to settle; absolute phase timing
			// absorbs this delay rather than adding it to each Morse element.
			time.Sleep(2 * time.Millisecond)
			actual, err := duty(l.files[channel])
			if err != nil {
				return err
			}
			if err := json.NewEncoder(l.trace).Encode(map[string]any{
				"time_us": time.Since(l.started).Microseconds(), "channel": channel,
				"requested": value, "actual": actual,
			}); err != nil {
				return err
			}
			if actual != value {
				return fmt.Errorf("channel %d readback mismatch: %d != %d", channel, actual, value)
			}
		}
	}
	return nil
}
func (l *nativeLights) Set(lit bool) error {
	value := uint32(0)
	if lit {
		value = completionLampDuty
	}
	values := map[int]uint32{}
	for _, channel := range l.channels {
		values[channel] = value
	}
	return l.Restore(values)
}
func (l *nativeLights) Green(on bool) error {
	if l.led == nil {
		return nil
	}
	green := byte(0)
	if on {
		green = 255
	}
	for _, pair := range [][2]byte{{2, 0}, {3, green}, {4, 0}} {
		if n, err := l.led.Write(pair[:]); err != nil {
			return err
		} else if n != 2 {
			return fmt.Errorf("short LED write")
		}
	}
	return nil
}
func (l *nativeLights) Close() {
	for _, file := range l.files {
		file.Close()
	}
	if l.led != nil {
		l.led.Close()
	}
	if l.trace != nil {
		l.trace.Close()
	}
}
