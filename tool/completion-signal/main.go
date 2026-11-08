package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
)

type snapshot struct {
	RunID      string         `json:"run_id"`
	Invocation string         `json:"invocation"`
	Duties     map[int]uint32 `json:"duties"`
}

func saveSnapshot(path string, value snapshot) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	file, err := os.OpenFile(path+".tmp", os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	if _, err = file.Write(data); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err = errors.Join(err, closeErr); err != nil {
		return err
	}
	if err = os.Rename(path+".tmp", path); err != nil {
		return err
	}
	dir, err := os.Open(filepath.Dir(path))
	if err != nil {
		return err
	}
	defer dir.Close()
	return dir.Sync()
}

func run() (err error) {
	runID := flag.String("run-id", "", "installer run identity")
	invocation := flag.String("invocation", "", "vehicle-service invocation")
	duration := flag.Duration("duration", maxDuration, "maximum signal duration")
	channelList := flag.String("channels", "1,2", "permitted PWM channels")
	noDashboard := flag.Bool("no-dashboard-led", false, "do not touch the dashboard LED")
	cleanup := flag.Bool("cleanup", false, "release this run's hold and restore lights")
	trace := flag.String("trace", "", "optional PWM readback trace")
	flag.Parse()
	if !regexp.MustCompile(`^[A-Za-z0-9_-][A-Za-z0-9._-]*$`).MatchString(*runID) ||
		!regexp.MustCompile(`^[a-f0-9]{32}$`).MatchString(*invocation) || *duration <= 0 || *duration > maxDuration {
		return fmt.Errorf("invalid run identity, vehicle invocation or duration")
	}
	var channels []int
	seen := map[int]bool{}
	for _, item := range strings.Split(*channelList, ",") {
		channel, parseErr := strconv.Atoi(item)
		if parseErr != nil || (channel != 1 && channel != 2) || seen[channel] {
			return fmt.Errorf("invalid PWM channel")
		}
		seen[channel] = true
		channels = append(channels, channel)
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	statePath, readyPath := executable+".state", executable+".ready"
	redis, err := connectRedis()
	if err != nil {
		return err
	}
	defer redis.conn.Close()
	var saved snapshot
	if *cleanup {
		if err := releaseHold(redis, *runID); err != nil {
			return err
		}
		data, err := os.ReadFile(statePath)
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		if err != nil {
			return err
		}
		if err := json.Unmarshal(data, &saved); err != nil {
			return err
		}
		if saved.RunID != *runID || saved.Invocation != *invocation {
			return fmt.Errorf("snapshot belongs to another run")
		}
		channels = nil
		for channel := range saved.Duties {
			if channel != 1 && channel != 2 {
				return fmt.Errorf("invalid saved channel")
			}
			channels = append(channels, channel)
		}
	}
	owner, err := observeOwner(*invocation)
	if err != nil {
		return err
	}
	state, err := redis.Command("HGET", "vehicle", "state")
	if err != nil {
		return err
	}
	if state != "stand-by" || !owner.Current() {
		return nil
	}
	lamps, err := openLights(channels, !*noDashboard, *trace)
	if err != nil {
		return err
	}
	defer lamps.Close()
	if !*cleanup {
		duties, err := lamps.Snapshot()
		if err != nil {
			return err
		}
		saved = snapshot{*runID, *invocation, duties}
		if err := saveSnapshot(statePath, saved); err != nil {
			return err
		}
	}
	defer func() {
		if owner.Current() {
			state, checkErr := redis.Command("HGET", "vehicle", "state")
			if checkErr == nil && state == "stand-by" {
				err = errors.Join(err, lamps.Restore(saved.Duties), lamps.Green(false))
			}
		}
		os.Remove(readyPath)
	}()
	if *cleanup {
		return nil
	}
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	return play(ctx, redis, lamps, owner.Current, *runID, *duration, realClock{}, func() error {
		return os.WriteFile(readyPath, []byte("ready\n"), 0600)
	})
}

func main() {
	if err := run(); err != nil {
		log.Printf("completion signal: %v", err)
		os.Exit(1)
	}
}
