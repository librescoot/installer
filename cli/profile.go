package main

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

// Profile is the parsed form of a TOML profile file. Sections map directly
// to settings-service prefixes (scooter.*, alarm.*, dashboard.*, cellular.*,
// engine-ecu.*, pm.*, updates.*). The [keycards] section is treated specially:
// master_uids/authorized_uids end up in /data/keycard/*.txt rather than Redis.
type Profile struct {
	// Settings is a flat map of "section.key" → string value (already TOML-quoted-stripped).
	Settings map[string]string
	// Keycards mirrors /data/keycard/{master,authorized}_uids.txt verbatim.
	MasterUIDs     []string
	AuthorizedUIDs []string
}

func loadProfile(path string) (*Profile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parseProfile(string(data))
}

// parseProfile reads a small subset of TOML: [section] headers, key = value
// scalars (string/bool/number), and inline arrays of strings. Sufficient for
// what the installer needs; we don't need full TOML.
func parseProfile(text string) (*Profile, error) {
	p := &Profile{Settings: map[string]string{}}
	section := ""
	for ln, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			continue
		}
		eq := strings.IndexByte(line, '=')
		if eq < 0 {
			return nil, fmt.Errorf("line %d: expected key = value: %q", ln+1, line)
		}
		key := strings.TrimSpace(line[:eq])
		val := strings.TrimSpace(line[eq+1:])

		if section == "keycards" {
			arr, err := parseArray(val)
			if err != nil {
				return nil, fmt.Errorf("line %d: %w", ln+1, err)
			}
			switch key {
			case "master_uids":
				p.MasterUIDs = append(p.MasterUIDs, normaliseUIDs(arr)...)
			case "authorized_uids":
				p.AuthorizedUIDs = append(p.AuthorizedUIDs, normaliseUIDs(arr)...)
			default:
				return nil, fmt.Errorf("line %d: unknown keycards key %q (expected master_uids or authorized_uids)", ln+1, key)
			}
			continue
		}

		fullKey := key
		if section != "" {
			fullKey = section + "." + key
		}
		stripped, err := parseScalar(val)
		if err != nil {
			return nil, fmt.Errorf("line %d: %w", ln+1, err)
		}
		p.Settings[fullKey] = stripped
	}
	return p, nil
}

func parseScalar(v string) (string, error) {
	if v == "" {
		return "", fmt.Errorf("empty value")
	}
	if (strings.HasPrefix(v, `"`) && strings.HasSuffix(v, `"`)) ||
		(strings.HasPrefix(v, `'`) && strings.HasSuffix(v, `'`)) {
		inner := v[1 : len(v)-1]
		// Minimal escape handling — \" only.
		inner = strings.ReplaceAll(inner, `\"`, `"`)
		return inner, nil
	}
	return v, nil
}

func parseArray(v string) ([]string, error) {
	if !strings.HasPrefix(v, "[") || !strings.HasSuffix(v, "]") {
		return nil, fmt.Errorf("expected inline array, got %q", v)
	}
	inner := strings.TrimSpace(v[1 : len(v)-1])
	if inner == "" {
		return nil, nil
	}
	var out []string
	for _, part := range strings.Split(inner, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		s, err := parseScalar(part)
		if err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, nil
}

func normaliseUIDs(uids []string) []string {
	out := make([]string, 0, len(uids))
	for _, u := range uids {
		u = strings.ToUpper(strings.ReplaceAll(u, " ", ""))
		u = strings.ReplaceAll(u, ":", "")
		u = strings.ReplaceAll(u, "-", "")
		if u != "" {
			out = append(out, u)
		}
	}
	return out
}

// applyProfile writes the profile contents onto the MDB:
//   - Each setting → HSET settings <key> <val>; PUBLISH settings <key>
//   - Keycard UIDs → atomic write of /data/keycard/{master,authorized}_uids.txt
//
// settings-service is event-driven (watches Redis pub/sub on "settings") so
// no service restart is needed. Keycard-service polls its files so the new
// UIDs become live on its next read.
func (inst *Installer) applyProfile(p *Profile) error {
	if len(p.Settings) > 0 {
		logStep("Applying %d settings to Redis...", len(p.Settings))
		keys := make([]string, 0, len(p.Settings))
		for k := range p.Settings {
			keys = append(keys, k)
		}
		sort.Strings(keys)

		// Pipe HSETs + PUBLISHes through redis-cli via a heredoc so we
		// avoid argv-quoting hell on weird values.
		var b strings.Builder
		for _, k := range keys {
			fmt.Fprintf(&b, "HSET settings %s %s\n", redisQuote(k), redisQuote(p.Settings[k]))
		}
		for _, k := range keys {
			fmt.Fprintf(&b, "PUBLISH settings %s\n", redisQuote(k))
		}
		script := fmt.Sprintf("redis-cli <<'PROFILE_EOF'\n%sPROFILE_EOF\n", b.String())
		if _, err := inst.mdbSSH(script); err != nil {
			return fmt.Errorf("applying settings: %w", err)
		}
		for _, k := range keys {
			logInfo("  %s = %s", k, abbreviate(p.Settings[k], 60))
		}
	}

	if len(p.MasterUIDs) > 0 || len(p.AuthorizedUIDs) > 0 {
		logStep("Pre-seeding keycard UIDs under /data/keycard/...")
		if _, err := inst.mdbSSH("mkdir -p /data/keycard"); err != nil {
			return fmt.Errorf("mkdir /data/keycard: %w", err)
		}
		if len(p.MasterUIDs) > 0 {
			content := strings.Join(p.MasterUIDs, "\n") + "\n"
			if err := inst.atomicWriteMDB("/data/keycard/master_uids.txt", content); err != nil {
				return fmt.Errorf("writing master_uids.txt: %w", err)
			}
			logInfo("  master_uids: %d", len(p.MasterUIDs))
		}
		if len(p.AuthorizedUIDs) > 0 {
			content := strings.Join(p.AuthorizedUIDs, "\n") + "\n"
			if err := inst.atomicWriteMDB("/data/keycard/authorized_uids.txt", content); err != nil {
				return fmt.Errorf("writing authorized_uids.txt: %w", err)
			}
			logInfo("  authorized_uids: %d", len(p.AuthorizedUIDs))
		}
	}

	return nil
}

// atomicWriteMDB writes content to remotePath using the tmp+sync+rename
// pattern keycard-service expects. Matches the spec atomicity guarantee.
func (inst *Installer) atomicWriteMDB(remotePath, content string) error {
	if err := inst.mdbWriteFile(remotePath+".tmp", []byte(content), "0644"); err != nil {
		return err
	}
	cmd := fmt.Sprintf("sync %s && mv %s %s",
		shellQuote(remotePath+".tmp"),
		shellQuote(remotePath+".tmp"),
		shellQuote(remotePath))
	_, err := inst.mdbSSH(cmd)
	return err
}

// redisQuote wraps a value for redis-cli inline script syntax. Spaces and
// double quotes need escaping; everything else is fine because we send via
// a heredoc.
func redisQuote(s string) string {
	if !strings.ContainsAny(s, ` "\t`) {
		return s
	}
	return `"` + strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`) + `"`
}
