package main

import (
	"fmt"
	"os"
	"strings"
)

var verbose = false

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func logStep(format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("\n==> %s\n", msg)
}

func logInfo(format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("    %s\n", msg)
}

func logWarn(format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(os.Stderr, "warning: %s\n", msg)
}

func logCmd(cmd string) {
	if !verbose {
		return
	}
	display := cmd
	if i := strings.Index(display, "sshpass"); i >= 0 {
		rest := display[i:]
		if root := strings.Index(rest, "root@"); root >= 0 {
			display = "[ssh] " + rest[root:]
		}
	}
	fmt.Printf("    $ %s\n", display)
}
