//go:build darwin

package main

/*
#cgo LDFLAGS: -framework Security
#include <Security/Authorization.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// authorize requests authorization for readwrite access to the given path.
// On success, writes the 32-byte external form to ext_out and returns 0.
static int authorize(const char *device_path, void *ext_out) {
	char right_name[512];
	snprintf(right_name, sizeof(right_name), "sys.openfile.readwrite.%s", device_path);

	AuthorizationItem item = { right_name, 0, NULL, 0 };
	AuthorizationRights rights = { 1, &item };
	AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed |
	                           kAuthorizationFlagExtendRights |
	                           kAuthorizationFlagPreAuthorize;

	AuthorizationRef ref = NULL;
	OSStatus status = AuthorizationCreate(&rights, NULL, flags, &ref);
	if (status != errAuthorizationSuccess) {
		fprintf(stderr, "Authorization failed: %d\n", (int)status);
		return (int)status;
	}

	AuthorizationExternalForm ext;
	status = AuthorizationMakeExternalForm(ref, &ext);
	AuthorizationFree(ref, kAuthorizationFlagDefaults);
	if (status != errAuthorizationSuccess) {
		fprintf(stderr, "AuthorizationMakeExternalForm failed: %d\n", (int)status);
		return (int)status;
	}

	memcpy(ext_out, ext.bytes, sizeof(ext.bytes));
	return 0;
}
*/
import "C"

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"syscall"
	"unsafe"
)

func openDevicePlatform(path string) (*os.File, error) {
	// Get authorization token via Security.framework
	var extForm [32]byte
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))

	rc := C.authorize(cPath, unsafe.Pointer(&extForm[0]))
	if rc != 0 {
		return nil, fmt.Errorf("authorization failed: %d", rc)
	}

	// Create unix socket pair for fd passing
	fds, err := syscall.Socketpair(syscall.AF_UNIX, syscall.SOCK_STREAM, 0)
	if err != nil {
		return nil, fmt.Errorf("socketpair: %w", err)
	}
	parentSock := os.NewFile(uintptr(fds[0]), "parent-sock")
	childSock := os.NewFile(uintptr(fds[1]), "child-sock")

	// Launch authopen: reads auth token from stdin, sends fd via stdout socket
	modeStr := strconv.Itoa(syscall.O_RDWR)
	cmd := exec.Command("/usr/libexec/authopen",
		"-stdoutpipe", "-extauth",
		"-o", modeStr,
		path,
	)
	cmd.Stdout = childSock
	cmd.Stderr = os.Stderr

	// Pipe auth token to authopen's stdin
	stdin, err := cmd.StdinPipe()
	if err != nil {
		parentSock.Close()
		childSock.Close()
		return nil, fmt.Errorf("stdin pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		parentSock.Close()
		childSock.Close()
		return nil, fmt.Errorf("starting authopen: %w", err)
	}
	childSock.Close() // parent doesn't need this end

	// Send the auth external form
	if _, err := stdin.Write(extForm[:]); err != nil {
		parentSock.Close()
		cmd.Wait()
		return nil, fmt.Errorf("writing auth token: %w", err)
	}
	stdin.Close()

	// Receive the device fd via SCM_RIGHTS
	deviceFd, err := receiveFd(int(parentSock.Fd()))
	parentSock.Close()
	cmd.Wait()

	if err != nil {
		return nil, fmt.Errorf("receiving device fd: %w", err)
	}

	// Set F_NOCACHE for direct I/O
	syscall.Syscall(syscall.SYS_FCNTL, uintptr(deviceFd), syscall.F_NOCACHE, 1)

	return os.NewFile(uintptr(deviceFd), path), nil
}

func receiveFd(sock int) (int, error) {
	// Use net.FileConn for cleaner SCM_RIGHTS handling
	f := os.NewFile(uintptr(sock), "sock")
	defer f.Close()

	conn, err := net.FileConn(f)
	if err != nil {
		return -1, err
	}
	defer conn.Close()

	uc, ok := conn.(*net.UnixConn)
	if !ok {
		return -1, fmt.Errorf("not a unix connection")
	}

	buf := make([]byte, 1)
	oob := make([]byte, syscall.CmsgLen(4))
	_, oobn, _, _, err := uc.ReadMsgUnix(buf, oob)
	if err != nil {
		return -1, fmt.Errorf("recvmsg: %w", err)
	}

	msgs, err := syscall.ParseSocketControlMessage(oob[:oobn])
	if err != nil {
		return -1, fmt.Errorf("parsing control message: %w", err)
	}

	for _, msg := range msgs {
		fds, err := syscall.ParseUnixRights(&msg)
		if err != nil {
			continue
		}
		if len(fds) > 0 {
			return fds[0], nil
		}
	}

	return -1, fmt.Errorf("no fd received from authopen")
}
