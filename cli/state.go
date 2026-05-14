package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

const stateFilePath = "/data/installer/state.json"

// Phase enumerates the major checkpoints in the install flow. Stored in the
// MDB-side state.json so any CLI invocation can pick up where the previous
// one left off.
type Phase string

const (
	PhaseFresh         Phase = ""                 // nothing installed yet
	PhaseMDBPrepped    Phase = "mdb-prepped"      // bootloader set, ready to UMS
	PhaseMDBFlashed    Phase = "mdb-flashed"      // image written, awaiting power cycle
	PhaseMDBBooted     Phase = "mdb-booted"       // booted into Librescoot, no DBC yet
	PhaseDBCStaged     Phase = "dbc-staged"       // artifacts on /data/installer
	PhaseTrampolineRun Phase = "trampoline-run"   // nohup trampoline.sh started
	PhaseTrampolineOK  Phase = "trampoline-ok"    // trampoline reported success
	PhaseTrampolineErr Phase = "trampoline-err"   // trampoline reported failure
	PhaseFinished      Phase = "finished"         // finish phase ran, scooter rebooted
)

// State is persisted at /data/installer/state.json on the MDB. The host CLI
// reads/writes it via SSH; the MDB itself never reads or writes it from any
// service. Survives moving between host machines.
type State struct {
	Phase       Phase     `json:"phase"`
	Channel     string    `json:"channel,omitempty"`
	ReleaseTag  string    `json:"release_tag,omitempty"`
	Serial      string    `json:"serial,omitempty"`
	MDBVersion  string    `json:"mdb_version,omitempty"`
	DBCImage    string    `json:"dbc_image,omitempty"`     // basename on MDB
	OSMTiles    string    `json:"osm_tiles,omitempty"`     // basename on MDB
	ValhallaTar string    `json:"valhalla_tiles,omitempty"`// basename on MDB
	Region      string    `json:"region,omitempty"`
	Language    string    `json:"language,omitempty"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (inst *Installer) loadState() (*State, error) {
	raw, err := inst.mdbReadFile(stateFilePath)
	if err != nil {
		return nil, err
	}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return &State{Phase: PhaseFresh}, nil
	}
	st := &State{}
	if err := json.Unmarshal([]byte(raw), st); err != nil {
		return nil, fmt.Errorf("parsing state.json: %w", err)
	}
	return st, nil
}

func (inst *Installer) saveState(st *State) error {
	st.UpdatedAt = time.Now().UTC()
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return inst.mdbWriteFile(stateFilePath, data, "0644")
}

// detectPhase probes the live state of the scooter to figure out where we
// are when no state.json exists yet. Used by `auto` mode against scooters
// that were partially installed by an older CLI or by the Flutter installer.
func (inst *Installer) detectPhase() (*State, error) {
	st, err := inst.loadState()
	if err == nil && st.Phase != PhaseFresh {
		return st, nil
	}

	// No state file. Probe.
	st = &State{Phase: PhaseFresh}

	out, _ := inst.mdbSSHOnce("test -f /data/installer/trampoline-status && cat /data/installer/trampoline-status | head -1")
	switch strings.TrimSpace(strings.SplitN(out, "\n", 2)[0]) {
	case "success":
		st.Phase = PhaseTrampolineOK
	case "rebooting":
		st.Phase = PhaseTrampolineRun
	default:
		if strings.HasPrefix(out, "error") {
			st.Phase = PhaseTrampolineErr
		}
	}

	if st.Phase != PhaseFresh {
		return st, nil
	}

	// No trampoline marker. If we can SSH and /etc/os-release looks like
	// Librescoot, the MDB has at least booted post-flash.
	info, err := inst.getMDBInfo()
	if err != nil {
		return st, nil
	}
	st.MDBVersion = info["version"]
	st.Serial = info["serial"]
	if name, ok := info["pretty_name"]; ok && strings.Contains(strings.ToLower(name), "librescoot") {
		st.Phase = PhaseMDBBooted
	}
	return st, nil
}
