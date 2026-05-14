package main

import (
	"flag"
	"fmt"
	"os"
	"time"
)

var version = "dev"

const usageText = `librescoot-install — install Librescoot on a connected MDB

Usage: librescoot-install [global flags] <command> [command flags]

Commands:
  install        run the full sequential flow (phase1 + phase2 + phase3) with prompts
  phase1         flash MDB and boot it into Librescoot (host-attended)
  phase2         stage DBC artifacts and start the trampoline (detaches on MDB)
  phase3         finish: persist channel, unlock, start keycard, reboot
  auto           detect current phase and run the next applicable one
  station        long-running loop: auto-run phase when scooter connects, prompt to swap
  apply-profile  push a TOML profile (settings + keycard UIDs) to a scooter

Global flags:
  --host         MDB IP (default 192.168.7.1)
  --password     MDB root SSH password (or env MDB_PASSWORD)
  --cache-dir    download cache (~/.cache/librescoot default)
  --dry-run      show what would happen
  --yes          skip confirmation prompts
  -v             show version
  --verbose      show executed commands
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usageText)
		os.Exit(1)
	}
	cmd := os.Args[1]
	switch cmd {
	case "-v", "--version":
		fmt.Println(version)
		return
	case "-h", "--help", "help":
		fmt.Print(usageText)
		return
	case "install":
		runInstall(os.Args[2:])
	case "phase1":
		runPhase("phase1", os.Args[2:])
	case "phase2":
		runPhase("phase2", os.Args[2:])
	case "phase3":
		runPhase("phase3", os.Args[2:])
	case "auto":
		runPhase("auto", os.Args[2:])
	case "station":
		runPhase("station", os.Args[2:])
	case "apply-profile":
		runApplyProfile(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %q\n\n%s", cmd, usageText)
		os.Exit(1)
	}
}

// commonFlags is shared across commands; returns a parsed Installer with the
// global flags filled in (but no command-specific behavior).
func commonFlags(name string, args []string, withReleaseFlags bool) (*Installer, *flag.FlagSet) {
	fs := flag.NewFlagSet(name, flag.ExitOnError)
	host := fs.String("host", "192.168.7.1", "MDB IP address")
	password := fs.String("password", "", "MDB root SSH password (or MDB_PASSWORD env)")
	cacheDir := fs.String("cache-dir", "", "Download cache directory (default: ~/.cache/librescoot)")
	dryRun := fs.Bool("dry-run", false, "Show what would be done")
	yes := fs.Bool("yes", false, "Skip confirmation prompts")
	verboseFlag := fs.Bool("verbose", false, "Show executed commands")

	var channel, releaseTag, image, dbcImage, dbcBmap, osmTiles, valTiles, region, language string
	if withReleaseFlags {
		fs.StringVar(&channel, "channel", "", "Release channel (testing, nightly)")
		fs.StringVar(&releaseTag, "version", "", "Specific release tag")
		fs.StringVar(&image, "image", "", "Local MDB image path (skip download)")
		fs.StringVar(&dbcImage, "dbc-image", "", "Local DBC image path (skip download)")
		fs.StringVar(&dbcBmap, "dbc-bmap", "", "Local DBC bmap path (optional)")
		fs.StringVar(&osmTiles, "osm-tiles", "", "Local OSM .mbtiles path (optional)")
		fs.StringVar(&valTiles, "valhalla-tiles", "", "Local Valhalla tiles tar path (optional)")
		fs.StringVar(&region, "region", "", "Region label stored in state (informational)")
		fs.StringVar(&language, "language", "", "Dashboard language to set at finish (e.g. en, de)")
	}

	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}

	if *password == "" {
		*password = os.Getenv("MDB_PASSWORD")
	}
	if *password == "" {
		fatal("--password or MDB_PASSWORD required")
	}

	if *cacheDir == "" {
		home, _ := os.UserHomeDir()
		*cacheDir = home + "/.cache/librescoot"
	}

	verbose = *verboseFlag

	inst := &Installer{
		mdbHost:      *host,
		mdbPassword:  *password,
		cacheDir:     *cacheDir,
		dryRun:       *dryRun,
		yes:          *yes,
		channel:      channel,
		releaseTag:   releaseTag,
		imagePath:    image,
		dbcImagePath: dbcImage,
		dbcBmapPath:  dbcBmap,
		osmTilesPath: osmTiles,
		valTilesPath: valTiles,
		region:       region,
		language:     language,
		timeout:      10 * time.Minute,
	}
	return inst, fs
}

// resolveImages downloads / locates the firmware images this run needs.
// Skips DBC if `dbcOptional` and no flag was passed.
func resolveImages(inst *Installer, needMDB, needDBC bool) {
	if needMDB && inst.imagePath == "" {
		tag := inst.releaseTag
		if tag == "" {
			if inst.channel == "" {
				fatal("one of --channel, --version, or --image is required for the MDB")
			}
			logStep("Resolving latest %s release...", inst.channel)
			t, err := findLatestRelease(inst.channel)
			if err != nil {
				fatal("failed to find release: %v", err)
			}
			tag = t
			inst.releaseTag = tag
			logInfo("Found release: %s", tag)
		}
		logStep("Downloading MDB firmware...")
		p, err := downloadMDBImage(tag, inst.cacheDir)
		if err != nil {
			fatal("failed to download MDB firmware: %v", err)
		}
		inst.imagePath = p
		if bmap := downloadMDBBmap(tag, inst.cacheDir); bmap != "" {
			inst.bmapPath = bmap
		}
	}

	if needDBC && inst.dbcImagePath == "" {
		tag := inst.releaseTag
		if tag == "" {
			if inst.channel == "" {
				logWarn("No --channel/--version set; skipping DBC download (pass --dbc-image to provide one)")
				return
			}
			t, err := findLatestRelease(inst.channel)
			if err != nil {
				fatal("failed to resolve release for DBC: %v", err)
			}
			tag = t
			inst.releaseTag = tag
		}
		logStep("Downloading DBC firmware...")
		p, err := downloadDBCImage(tag, inst.cacheDir)
		if err != nil {
			logWarn("DBC download failed: %v", err)
			return
		}
		inst.dbcImagePath = p
		if bmap := downloadDBCBmap(tag, inst.cacheDir); bmap != "" {
			inst.dbcBmapPath = bmap
		}
	}
}

func runInstall(args []string) {
	inst, _ := commonFlags("install", args, true)
	resolveImages(inst, true, true)
	if err := inst.runFull(); err != nil {
		fatal("%v", err)
	}
}

func runPhase(name string, args []string) {
	withRelease := name == "phase1" || name == "phase2" || name == "auto" || name == "station"
	inst, _ := commonFlags(name, args, withRelease)
	if withRelease {
		resolveImages(inst, name == "phase1" || name == "auto" || name == "station", name == "phase2" || name == "auto" || name == "station")
	}
	var err error
	switch name {
	case "phase1":
		err = inst.runPhase1()
	case "phase2":
		err = inst.runPhase2()
	case "phase3":
		err = inst.runPhase3()
	case "auto":
		err = inst.runAuto()
	case "station":
		err = inst.runStation()
	}
	if err != nil {
		fatal("%v", err)
	}
}

func runApplyProfile(args []string) {
	fs := flag.NewFlagSet("apply-profile", flag.ExitOnError)
	host := fs.String("host", "192.168.7.1", "MDB IP address")
	password := fs.String("password", "", "MDB root SSH password (or MDB_PASSWORD env)")
	file := fs.String("file", "", "Path to TOML profile (required)")
	dryRun := fs.Bool("dry-run", false, "Print what would be applied, don't write")
	verboseFlag := fs.Bool("verbose", false, "Show executed commands")
	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}
	if *password == "" {
		*password = os.Getenv("MDB_PASSWORD")
	}
	if *password == "" {
		fatal("--password or MDB_PASSWORD required")
	}
	if *file == "" {
		fatal("--file is required")
	}
	verbose = *verboseFlag

	p, err := loadProfile(*file)
	if err != nil {
		fatal("loading profile: %v", err)
	}
	logInfo("Profile: %d settings, %d master UID(s), %d authorized UID(s)",
		len(p.Settings), len(p.MasterUIDs), len(p.AuthorizedUIDs))

	if *dryRun {
		for k, v := range p.Settings {
			fmt.Printf("  set %s = %s\n", k, v)
		}
		for _, u := range p.MasterUIDs {
			fmt.Printf("  master_uid %s\n", u)
		}
		for _, u := range p.AuthorizedUIDs {
			fmt.Printf("  authorized_uid %s\n", u)
		}
		return
	}

	inst := &Installer{mdbHost: *host, mdbPassword: *password}
	logStep("Connecting to MDB at %s...", *host)
	if _, err := inst.getMDBInfo(); err != nil {
		fatal("SSH to MDB failed: %v", err)
	}
	if err := inst.applyProfile(p); err != nil {
		fatal("applying profile: %v", err)
	}
	logStep("Profile applied.")
}
