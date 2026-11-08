package main

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"
)

type fakeClock struct{ now time.Time }

func (c *fakeClock) Now() time.Time { return c.now }
func (c *fakeClock) Wait(ctx context.Context, d time.Duration) error {
	c.now = c.now.Add(d)
	return ctx.Err()
}

type fakeRedis struct {
	calls []string
	state func() string
}

func (r *fakeRedis) Command(args ...string) (string, error) {
	r.calls = append(r.calls, strings.Join(args, " "))
	if len(args) == 3 && args[0] == "HGET" {
		return r.state(), nil
	}
	return "1", nil
}

type event struct {
	at  time.Duration
	lit bool
}
type fakeLights struct {
	clock  *fakeClock
	events []event
	green  bool
}

func (l *fakeLights) Set(lit bool) error {
	l.events = append(l.events, event{l.clock.now.Sub(time.Unix(0, 0)), lit})
	return nil
}
func (l *fakeLights) Green(on bool) error { l.green = on; return nil }

func TestMorseFramesSpellLibrescoot(t *testing.T) {
	want := []string{".-..", "..", "-...", ".-.", ".", "...", "-.-.", "---", "---", "-"}
	if morse != strings.Join(want, " ") {
		t.Fatal(morse)
	}
	var letters []string
	var letter strings.Builder
	units := 0
	for _, f := range morseFrames() {
		units += f.units
		if f.lit {
			if f.units == 1 {
				letter.WriteByte('.')
			} else if f.units == 3 {
				letter.WriteByte('-')
			} else {
				t.Fatal(f)
			}
		} else if f.units >= 3 {
			letters = append(letters, letter.String())
			letter.Reset()
		}
	}
	if !reflect.DeepEqual(letters, want) || units != 104 {
		t.Fatalf("letters=%v units=%d", letters, units)
	}
}

func TestAbsoluteMorseTimingAndUnlock(t *testing.T) {
	clock := &fakeClock{now: time.Unix(0, 0)}
	redis := &fakeRedis{state: func() string {
		if clock.Now().Sub(time.Unix(0, 0)) >= 21000*time.Millisecond {
			return "parked"
		}
		return "stand-by"
	}}
	lamps := &fakeLights{clock: clock}
	if err := play(context.Background(), redis, lamps, func() bool { return true }, "test", maxDuration, clock, func() error { return nil }); err != nil {
		t.Fatal(err)
	}
	want := []event{{0, true}, {200 * time.Millisecond, false}, {400 * time.Millisecond, true}, {time.Second, false}, {1200 * time.Millisecond, true}, {1400 * time.Millisecond, false}, {1600 * time.Millisecond, true}, {1800 * time.Millisecond, false}, {2400 * time.Millisecond, true}}
	if len(lamps.events) < len(want) || !reflect.DeepEqual(lamps.events[:len(want)], want) {
		t.Fatalf("events: %v", lamps.events)
	}
	if lamps.events[len(lamps.events)-1] != (event{20800 * time.Millisecond, true}) {
		t.Fatalf("not stopped on unlock: %v", lamps.events[len(lamps.events)-1])
	}
	if !strings.Contains(strings.Join(redis.calls, "\n"), "HDEL power:inhibits installer-completion-test") {
		t.Fatal("hold not released")
	}
}

func TestFifteenMinuteCap(t *testing.T) {
	clock := &fakeClock{now: time.Unix(0, 0)}
	redis := &fakeRedis{state: func() string { return "stand-by" }}
	lamps := &fakeLights{clock: clock}
	if err := play(context.Background(), redis, lamps, func() bool { return true }, "test", maxDuration, clock, func() error { return nil }); err != nil {
		t.Fatal(err)
	}
	if elapsed := clock.Now().Sub(time.Unix(0, 0)); elapsed != maxDuration {
		t.Fatalf("elapsed=%v", elapsed)
	}
}

func TestStartupFailureReleasesHoldAndNeverSignals(t *testing.T) {
	clock := &fakeClock{now: time.Unix(0, 0)}
	redis := &fakeRedis{state: func() string { return "stand-by" }}
	lamps := &fakeLights{clock: clock}
	if err := play(context.Background(), redis, lamps, func() bool { return true }, "test", maxDuration, clock, func() error { return errors.New("no ready file") }); err == nil {
		t.Fatal("expected error")
	}
	if len(lamps.events) != 0 {
		t.Fatal(lamps.events)
	}
	if !strings.Contains(strings.Join(redis.calls, "\n"), "HDEL power:inhibits installer-completion-test") {
		t.Fatal("hold not released")
	}
}

func TestUnknownOrNewOwnerDoesNotSignal(t *testing.T) {
	clock := &fakeClock{now: time.Unix(0, 0)}
	redis := &fakeRedis{state: func() string { return "parked" }}
	lamps := &fakeLights{clock: clock}
	if err := play(context.Background(), redis, lamps, func() bool { return true }, "test", time.Second, clock, func() error { return nil }); err != nil {
		t.Fatal(err)
	}
	if len(lamps.events) != 0 {
		t.Fatal(lamps.events)
	}
	redis.state = func() string { return "stand-by" }
	if err := play(context.Background(), redis, lamps, func() bool { return false }, "test", time.Second, clock, func() error { return nil }); err != nil {
		t.Fatal(err)
	}
	if len(lamps.events) != 0 {
		t.Fatal(lamps.events)
	}
}

func TestLampDutyStaysBelowParkingLightPeak(t *testing.T) {
	if completionLampDuty != 1000 || completionLampDuty >= 2200 {
		t.Fatal(completionLampDuty)
	}
}
