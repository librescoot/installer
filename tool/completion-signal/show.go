package main

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const morse = ".-.. .. -... .-. . ... -.-. --- --- -"
const morseUnit = 200 * time.Millisecond
const maxDuration = 15 * time.Minute

// Out of the 12000-count PWM period; the parking light peaks at 2200.
const completionLampDuty = 1000

// A dark frame separates marks, letters and repetitions by 1, 3 and 7 units.
type frame struct {
	lit   bool
	units int
}

func morseFrames() []frame {
	var frames []frame
	letters := []string{".-..", "..", "-...", ".-.", ".", "...", "-.-.", "---", "---", "-"}
	for i, letter := range letters {
		for j, mark := range letter {
			units := 1
			if mark == '-' {
				units = 3
			}
			frames = append(frames, frame{true, units})
			if j+1 < len(letter) {
				frames = append(frames, frame{false, 1})
			}
		}
		gap := 3
		if i+1 == len(letters) {
			gap = 7
		}
		frames = append(frames, frame{false, gap})
	}
	return frames
}

type commands interface {
	Command(...string) (string, error)
}
type lights interface {
	Set(bool) error
	Green(bool) error
}
type clock interface {
	Now() time.Time
	Wait(context.Context, time.Duration) error
}
type realClock struct{}

func (realClock) Now() time.Time { return time.Now() }
func (realClock) Wait(ctx context.Context, duration time.Duration) error {
	timer := time.NewTimer(duration)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return ctx.Err()
	}
}

func releaseHold(redis commands, runID string) error {
	id := "installer-completion-" + runID
	_, removeErr := redis.Command("HDEL", "power:inhibits", id)
	_, publishErr := redis.Command("PUBLISH", "power:inhibits", "remove:"+id)
	return errors.Join(removeErr, publishErr)
}

func play(ctx context.Context, redis commands, lamps lights, owner func() bool,
	runID string, duration time.Duration, clock clock, ready func() error) (err error) {
	if duration <= 0 || duration > maxDuration {
		return fmt.Errorf("invalid duration")
	}
	allowed := func() (bool, error) {
		if ctx.Err() != nil || !owner() {
			return false, nil
		}
		state, err := redis.Command("HGET", "vehicle", "state")
		return state == "stand-by", err
	}
	ok, err := allowed()
	if err != nil || !ok {
		return err
	}
	defer func() { err = errors.Join(err, releaseHold(redis, runID)) }()
	id := "installer-completion-" + runID
	if _, err := redis.Command("HSET", "power:inhibits", id,
		`{"who":"installer-completion","what":"completion lights","why":"waiting for the owner","type":"suspend-only"}`); err != nil {
		return err
	}
	if _, err := redis.Command("PUBLISH", "power:inhibits", "add:"+id); err != nil {
		return err
	}
	if err := lamps.Green(true); err != nil {
		return err
	}
	if err := ready(); err != nil {
		return err
	}
	phase := clock.Now()
	deadline := phase.Add(duration)
	frames := morseFrames()
	for {
		for _, frame := range frames {
			if !clock.Now().Before(deadline) {
				return nil
			}
			ok, err := allowed()
			if err != nil || !ok {
				return err
			}
			phase = phase.Add(time.Duration(frame.units) * morseUnit)
			// Scheduling stalls skip expired frames instead of replaying them.
			if !clock.Now().Before(phase) {
				continue
			}
			if err := lamps.Set(frame.lit); err != nil {
				return err
			}
			end := phase
			if deadline.Before(end) {
				end = deadline
			}
			for clock.Now().Before(end) {
				ok, err := allowed()
				if err != nil || !ok {
					return err
				}
				wait := end.Sub(clock.Now())
				if wait > 50*time.Millisecond {
					wait = 50 * time.Millisecond
				}
				if err := clock.Wait(ctx, wait); err != nil {
					return nil
				}
			}
		}
	}
}
