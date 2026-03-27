package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

var version = "dev"

func main() {
	channel := flag.String("channel", "", "Release channel: testing, nightly")
	releaseTag := flag.String("version", "", "Specific release tag (e.g. testing-20260318T114803)")
	imagePath := flag.String("image", "", "Path to firmware image (skip download)")
	mdbHost := flag.String("host", "192.168.7.1", "MDB IP address")
	mdbPassword := flag.String("password", "", "MDB root SSH password (or MDB_PASSWORD env)")
	cacheDir := flag.String("cache-dir", "", "Download cache directory (default: ~/.cache/librescoot)")
	dryRun := flag.Bool("dry-run", false, "Show what would be done")
	showVersion := flag.Bool("v", false, "Show version")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "librescoot-install %s — install LibreScoot on a connected MDB\n\n", version)
		fmt.Fprintf(os.Stderr, "Usage:\n")
		fmt.Fprintf(os.Stderr, "  librescoot-install --channel testing --password PASSWORD\n")
		fmt.Fprintf(os.Stderr, "  librescoot-install --image firmware.sdimg.gz --password PASSWORD\n\n")
		fmt.Fprintf(os.Stderr, "Flags:\n")
		flag.PrintDefaults()
	}

	flag.Parse()

	if *showVersion {
		fmt.Println(version)
		os.Exit(0)
	}

	if *mdbPassword == "" {
		*mdbPassword = os.Getenv("MDB_PASSWORD")
	}
	if *mdbPassword == "" {
		fatal("--password or MDB_PASSWORD required")
	}

	if *channel == "" && *releaseTag == "" && *imagePath == "" {
		fatal("one of --channel, --version, or --image is required")
	}

	if *cacheDir == "" {
		home, _ := os.UserHomeDir()
		*cacheDir = home + "/.cache/librescoot"
	}

	installer := &Installer{
		mdbHost:     *mdbHost,
		mdbPassword: *mdbPassword,
		cacheDir:    *cacheDir,
		dryRun:      *dryRun,
	}

	var err error

	// Resolve firmware image
	if *imagePath != "" {
		installer.imagePath = *imagePath
	} else {
		tag := *releaseTag
		if tag == "" {
			logStep("Resolving latest %s release...", *channel)
			tag, err = findLatestRelease(*channel)
			if err != nil {
				fatal("failed to find release: %v", err)
			}
			logInfo("Found release: %s", tag)
		}
		logStep("Downloading MDB firmware...")
		installer.imagePath, err = downloadMDBImage(tag, *cacheDir)
		if err != nil {
			fatal("failed to download firmware: %v", err)
		}
	}

	if err := installer.Run(); err != nil {
		fatal("%v", err)
	}
}

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
	// Truncate long commands for display, redact passwords
	display := cmd
	if i := strings.Index(display, "sshpass"); i >= 0 {
		display = "[ssh] " + display[strings.Index(display, "root@"):]
	}
	fmt.Printf("    $ %s\n", display)
}
