#!/bin/sh
# Librescoot install signalling. Sourced, never run.
#
# Everything the vehicle says about an install in progress lives here: the four
# blinkers as a progress bar, the front light as the "waiting for the dashboard"
# pulse, the dashboard's own LP5562 as the overall state, and the hazards as the
# failure signal.
#
# One copy, staged into the scripts directory beside the phases and sourced by
# the trampoline, by every phase, by the coordinator and by the rescue. It used
# to be defined twice, once in the trampoline and once inside the heredoc that
# writes the dashboard phase, with a test whose only job was to catch the two
# drifting apart.
#
# Sourcing is guarded everywhere ([ -f ] && .), so a run whose staging failed
# loses its lights rather than its install.

SIGNAL_INSTALLER_DIR="/data/installer"
# Shared with the trampoline's own bookkeeping: the bar has to survive the MDB
# reboot between the work and the handover, and a file is the only thing that
# does.
SIGNAL_STATE_FILE="$SIGNAL_INSTALLER_DIR/trampoline-phase"

signal_log() {
  echo "$(date '+%H:%M:%S') signal: $*" \
    >> "$SIGNAL_INSTALLER_DIR/trampoline.log" 2>/dev/null
}

# --- what this image can actually drive -----------------------------------
# The blinkers and the front light are a char device with custom ioctls and no
# sysfs, so the `ioctl` binary is the only way to reach them; the dashboard LED
# is an LP5562 on i2c-2 and wants i2cset. Both ship in the full image and in
# neither bootstrap image, and the autonomous half of an install runs on
# whichever of the two the board happens to be on. Resolve once, here, so a
# board that cannot light anything says so in the log instead of going quietly
# dark for twenty minutes.
SIGNAL_IOCTL=""
for signal_cand in "$SIGNAL_INSTALLER_DIR/ioctl" /usr/bin/ioctl; do
  if [ -x "$signal_cand" ]; then
    SIGNAL_IOCTL="$signal_cand"
    break
  fi
done
if [ -z "$SIGNAL_IOCTL" ]; then
  SIGNAL_IOCTL="$(command -v ioctl 2>/dev/null)"
fi
SIGNAL_I2CSET="$(command -v i2cset 2>/dev/null)"
unset signal_cand
[ -n "$SIGNAL_IOCTL" ] ||
  signal_log "no ioctl on this image, the blinker bar and the front light stay dark"
[ -n "$SIGNAL_I2CSET" ] ||
  signal_log "no i2cset on this image, the dashboard LED stays dark"

# --- PWM LED channels ------------------------------------------------------
# 0=headlight 1=front_ring 2=brake 3=FL 4=FR 5=plates 6=RL 7=RR
FRONT_LED=1
# Segment order: 1=FL, 2=RR, 3=FR, 4=RL. Unchanged from the bar this replaces,
# so a vehicle mid-run reads the same as it always did.
BLINKER_LEDS="3 7 4 6"
# Just under fade4's peak (156), so a breathing segment reads brighter at its
# peak than the filled trail behind it.
DIM_DUTY=150
# Breathing drives the duty directly rather than playing a fade. The fade
# tables ship with vehicle-service and are loaded by it, so on the bootstrap
# image every play is a no-op and the whole bar stays dark.
BREATHE_LOW=40
BREATHE_HIGH=400

led_activate() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  "$SIGNAL_IOCTL" "/dev/pwm_led$1" 0x00007549 -v 1 2>/dev/null
}
led_deactivate() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  "$SIGNAL_IOCTL" "/dev/pwm_led$1" 0x00007549 -v 0 2>/dev/null
}
led_duty() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  "$SIGNAL_IOCTL" "/dev/pwm_led$1" 0x0000754A -v "$2" 2>/dev/null
}
led_fade() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  "$SIGNAL_IOCTL" "/dev/pwm_led$1" 0x00007545 -v "$2" 2>/dev/null
}

# Dark, and still claimable. In the imx_pwm_led driver the active flag gates
# the PWM output: SET_ACTIVE 0 forces the duty to 0 whatever is loaded, and
# SET_DUTY only takes effect while the channel is active. vehicle-service sets
# activate=1 exactly once, in its own Init, and runBlinker afterwards only
# loads duties, so a channel this deactivates stays dead until vehicle-service
# re-inits. Duty 0 with activate=1 is the same darkness and hands the channel
# back in the state vehicle-service expects.
led_release() {
  led_duty "$1" 0
}

led_off() {
  led_duty "$1" 0
  led_deactivate "$1"
}

# --- the front light: "the main board is waiting for the dashboard" --------
# Its own state, deliberately separate from the bar. It runs from the moment
# the user is asked to move the cable until the dashboard answers, and nothing
# else in an install ever pulses it.
FRONT_PULSE_UNIT="librescoot-front-pulse"

# Its own transient unit for the same reason every other loop here has one: the
# scripts that start these are short-lived, and the coordinator runs phases
# under librescoot-onboot.service, which is Type=oneshot with the default
# KillMode=control-group and takes every descendant with it when the phase
# returns. setsid does not escape that; a separate unit does.
front_pulse_start() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  systemctl stop "$FRONT_PULSE_UNIT.service" 2>/dev/null
  systemd-run --unit="$FRONT_PULSE_UNIT" --collect --quiet --slice=system.slice \
    --setenv=BREATHE_LO="$BREATHE_LOW" --setenv=BREATHE_HI="$BREATHE_HIGH" \
    /bin/sh -c '
      IOCTL="$1"
      CH="$2"
      LO="$BREATHE_LO"
      HI="$BREATHE_HI"
      "$IOCTL" "/dev/pwm_led$CH" 0x00007549 -v 1 2>/dev/null
      while true; do
        "$IOCTL" "/dev/pwm_led$CH" 0x0000754A -v "$LO" 2>/dev/null
        sleep 3
        "$IOCTL" "/dev/pwm_led$CH" 0x0000754A -v "$HI" 2>/dev/null
        sleep 3
      done
    ' sh "$SIGNAL_IOCTL" "$FRONT_LED" 2>/dev/null
}

front_pulse_stop() {
  systemctl stop "$FRONT_PULSE_UNIT.service" 2>/dev/null
  led_off "$FRONT_LED"
}

# --- the blinker bar -------------------------------------------------------
# Four segments, one per stage of an install:
#
#   1  preparation   the dashboard rebooted into mass storage, stage-0 image
#                    being written
#   2  main board    its own .mender installing
#   3  dashboard     its .mender, plus the map and routing tiles
#   4  handover      settings restored, service mode ended, unlocking
#
# 2 and 3 genuinely overlap: the main board writes its own eMMC while the
# dashboard is being flashed and uploaded to, and 80-reboot.sh joins the two.
# So more than one segment can be active at a time and either can finish first,
# which is why the state is four independent segments rather than a phase
# number.
#
# The bar always reads left to right: every segment before the furthest one
# that is lit renders as filled, whether or not its stage ran. An upgrade
# writes no stage-0 image and a plan can leave the main board alone, and a
# bar with a dark gap in it reads as a fault, not as a stage that was skipped.
# The state file still records only what happened; the fill is applied when
# the bar is drawn.
#
# Persisted because the run reboots in the middle of itself: 80-reboot.sh asks
# the coordinator for the reboot and the coordinator lights the far side from
# this file.
#
# Filled segments hold a static dim glow; active segments breathe on fade4/fade9
# (brake-dim-on/off, duty ~48..180 of 12000).
SEGMENT_PREP=1
SEGMENT_MDB=2
SEGMENT_DBC=3
SEGMENT_HANDOVER=4
PROGRESS_BREATHE_UNIT="librescoot-progress-breathe"

# Four characters, one per segment: - off, * active, # done. Anything else is
# a file from another installer or a truncated write, and reads as all-off
# rather than lighting a segment at random.
progress_read() {
  signal_state="$(head -n1 "$SIGNAL_STATE_FILE" 2>/dev/null)"
  case "$signal_state" in
    [-*#][-*#][-*#][-*#]) printf '%s' "$signal_state" ;;
    *) printf '%s' '----' ;;
  esac
}

progress_write() {
  printf '%s\n' "$1" > "$SIGNAL_STATE_FILE" 2>/dev/null
}

# progress_set <segment 1-4> <off|active|done>
#
# Locked, because the two work halves run at the same time and both write this
# file: 10-mdb-artifact.sh fills segment 2 from a background job while
# 20-dbc.sh is filling segment 3. Unlocked, one of the two read-modify-writes
# loses, and the segment it dropped keeps breathing for a stage that finished.
# mkdir is the atomic create every shell has. A lock nobody released is taken
# after two seconds rather than waited on forever: a stuck bar is worse than
# a rare lost update, and the holder is a script that has already died.
progress_set() {
  case "$2" in
    off) signal_char='-' ;;
    active) signal_char='*' ;;
    done) signal_char='#' ;;
    *) return 1 ;;
  esac
  signal_i=0
  while ! mkdir "$SIGNAL_STATE_FILE.lock" 2>/dev/null; do
    signal_i=$((signal_i + 1))
    [ "$signal_i" -gt 20 ] && break
    sleep 0.1
  done
  signal_cur="$(progress_read)"
  signal_new=""
  signal_i=1
  while [ "$signal_i" -le 4 ]; do
    if [ "$signal_i" -eq "$1" ]; then
      signal_new="$signal_new$signal_char"
    else
      signal_new="$signal_new$(printf '%s' "$signal_cur" | cut -c"$signal_i")"
    fi
    signal_i=$((signal_i + 1))
  done
  progress_write "$signal_new"
  rmdir "$SIGNAL_STATE_FILE.lock" 2>/dev/null
  progress_render
}

# Drive the blinkers from the persisted state. Idempotent, and the only thing
# that ever touches them, so the coordinator can call it after a reboot and get
# the bar the run left behind.
progress_render() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  signal_state="$(progress_read)"
  # Furthest lit segment; everything before it is drawn filled.
  signal_last=0
  signal_i=1
  while [ "$signal_i" -le 4 ]; do
    case "$(printf '%s' "$signal_state" | cut -c"$signal_i")" in
      '#'|'*') signal_last="$signal_i" ;;
    esac
    signal_i=$((signal_i + 1))
  done
  signal_active=""
  signal_i=1
  for signal_l in $BLINKER_LEDS; do
    signal_c="$(printf '%s' "$signal_state" | cut -c"$signal_i")"
    [ "$signal_c" = '-' ] && [ "$signal_i" -lt "$signal_last" ] && signal_c='#'
    case "$signal_c" in
      '#')
        led_activate "$signal_l"
        led_duty "$signal_l" "$DIM_DUTY"
        ;;
      '*')
        led_activate "$signal_l"
        signal_active="$signal_active $signal_l"
        ;;
      *)
        led_release "$signal_l"
        ;;
    esac
    signal_i=$((signal_i + 1))
  done
  progress_breathe_stop
  [ -n "$signal_active" ] && progress_breathe_start $signal_active
  return 0
}

# One loop for however many segments are active, so two segments breathing
# together stay in step instead of drifting apart.
progress_breathe_start() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  systemd-run --unit="$PROGRESS_BREATHE_UNIT" --collect --quiet \
    --slice=system.slice \
    --setenv=BREATHE_LO="$BREATHE_LOW" --setenv=BREATHE_HI="$BREATHE_HIGH" \
    /bin/sh -c '
      IOCTL="$1"
      LO="$BREATHE_LO"
      HI="$BREATHE_HI"
      shift
      for ch in "$@"; do
        "$IOCTL" "/dev/pwm_led$ch" 0x00007549 -v 1 2>/dev/null
      done
      while true; do
        for ch in "$@"; do
          "$IOCTL" "/dev/pwm_led$ch" 0x0000754A -v "$LO" 2>/dev/null
        done
        sleep 3
        for ch in "$@"; do
          "$IOCTL" "/dev/pwm_led$ch" 0x0000754A -v "$HI" 2>/dev/null
        done
        sleep 3
      done
    ' sh "$SIGNAL_IOCTL" "$@" 2>/dev/null
}

progress_breathe_stop() {
  systemctl stop "$PROGRESS_BREATHE_UNIT.service" 2>/dev/null
}

# Bar dark and the state forgotten. For a run that is over, one way or another.
progress_off() {
  progress_breathe_stop
  for signal_l in $BLINKER_LEDS; do
    led_release "$signal_l"
  done
  rm -f "$SIGNAL_STATE_FILE"
  rmdir "$SIGNAL_STATE_FILE.lock" 2>/dev/null
}

# The same, with a ramp. Used once, at the end of a run that worked, so the bar
# releases with a fade rather than snapping off.
progress_fade_off() {
  progress_breathe_stop
  if [ -n "$SIGNAL_IOCTL" ]; then
    for signal_l in $BLINKER_LEDS; do
      led_activate "$signal_l"
    done
    for signal_d in 150 110 75 48 28 14 6 0; do
      for signal_l in $BLINKER_LEDS; do
        led_duty "$signal_l" "$signal_d"
      done
      sleep 0.12
    done
  fi
  rm -f "$SIGNAL_STATE_FILE"
  rmdir "$SIGNAL_STATE_FILE.lock" 2>/dev/null
}

# --- the dashboard LED (LP5562, i2c-2 @ 0x30) ------------------------------
# Amber for as long as an install is in progress, red blinking when one failed,
# dark when one worked. Not green on success: the vehicle unlocks itself at the
# end, and that is the signal the owner is waiting for.
bootled_init() {
  [ -n "$SIGNAL_I2CSET" ] || return 0
  i2cset -f -y 2 0x30 0x0D 0xFF
  i2cset -f -y 2 0x30 0x01 0x3F
  i2cset -f -y 2 0x30 0x70 0x00
  i2cset -f -y 2 0x30 0x08 0x61
  i2cset -f -y 2 0x30 0x00 0xC0
  i2cset -f -y 2 0x30 0x05 0xAF
  i2cset -f -y 2 0x30 0x06 0xAF
  i2cset -f -y 2 0x30 0x07 0xAF
} 2>/dev/null

bootled() {
  [ -n "$SIGNAL_I2CSET" ] || return 0
  case "$1" in
    amber) i2cset -f -y 2 0x30 0x02 0xFF; i2cset -f -y 2 0x30 0x03 0x00; i2cset -f -y 2 0x30 0x04 0x00 ;;
    red)   i2cset -f -y 2 0x30 0x02 0x00; i2cset -f -y 2 0x30 0x03 0x00; i2cset -f -y 2 0x30 0x04 0xFF ;;
    off)   i2cset -f -y 2 0x30 0x02 0x00; i2cset -f -y 2 0x30 0x03 0x00; i2cset -f -y 2 0x30 0x04 0x00 ;;
  esac
} 2>/dev/null

# vehicle-service drives the same LP5562 for blinker brightness and cannot be
# masked (the dashboard power dance needs it), so anything that fires a blinker
# stomps our amber with whatever brightness it wanted. Re-assert every 2s and
# any stray write loses within a tick.
BOOTLED_GUARD_UNIT="librescoot-bootled-guard"
bootled_guard_start() {
  [ -n "$SIGNAL_I2CSET" ] || return 0
  systemctl stop "$BOOTLED_GUARD_UNIT.service" 2>/dev/null
  systemd-run --unit="$BOOTLED_GUARD_UNIT" --collect --quiet --slice=system.slice /bin/sh -c '
    while true; do
      i2cset -f -y 2 0x30 0x02 0xFF 2>/dev/null
      i2cset -f -y 2 0x30 0x03 0x00 2>/dev/null
      i2cset -f -y 2 0x30 0x04 0x00 2>/dev/null
      sleep 2
    done
  ' 2>/dev/null
}
bootled_guard_stop() {
  systemctl stop "$BOOTLED_GUARD_UNIT.service" 2>/dev/null
}

BOOTLED_BLINK_UNIT="librescoot-bootled-blink"
bootled_blink_red() {
  bootled_blink_stop
  [ -n "$SIGNAL_I2CSET" ] || return 0
  systemd-run --unit="$BOOTLED_BLINK_UNIT" --collect --quiet --slice=system.slice /bin/sh -c '
    n=0
    while [ $n -lt 2250 ]; do
      n=$((n + 1))
      i2cset -f -y 2 0x30 0x02 0x00 2>/dev/null
      i2cset -f -y 2 0x30 0x03 0x00 2>/dev/null
      i2cset -f -y 2 0x30 0x04 0xFF 2>/dev/null
      sleep 0.4
      i2cset -f -y 2 0x30 0x02 0x00 2>/dev/null
      i2cset -f -y 2 0x30 0x03 0x00 2>/dev/null
      i2cset -f -y 2 0x30 0x04 0x00 2>/dev/null
      sleep 0.4
    done
  ' 2>/dev/null
}
bootled_blink_stop() {
  systemctl stop "$BOOTLED_BLINK_UNIT.service" 2>/dev/null
  # Older builds ran the blink from a PID file rather than a unit, and a resume
  # can meet one of those.
  if [ -f /data/bootled-blink.pid ]; then
    signal_pid="$(cat /data/bootled-blink.pid 2>/dev/null)"
    if [ -n "$signal_pid" ]; then
      kill -- -"$signal_pid" 2>/dev/null
      kill "$signal_pid" 2>/dev/null
    fi
    rm -f /data/bootled-blink.pid
  fi
}

# All four blinkers flashing in unison is the universal "this vehicle is in
# trouble" signal, and far more visible than the bar, which is what a failure
# needs: the owner is not standing at the dashboard. Capped at 30s so an
# abandoned failure cannot drain the battery.
HAZARDS_UNIT="librescoot-bootled-hazards"
hazards_start() {
  [ -n "$SIGNAL_IOCTL" ] || return 0
  hazards_stop
  systemd-run --unit="$HAZARDS_UNIT" --collect --quiet --slice=system.slice \
    /bin/sh -c '
      IOCTL="$1"
      DIM=2000
      for ch in 3 4 6 7; do
        "$IOCTL" "/dev/pwm_led$ch" 0x00007549 -v 1 2>/dev/null
      done
      end=$(( $(date +%s) + 30 ))
      while [ "$(date +%s)" -lt "$end" ]; do
        for ch in 3 4 6 7; do
          "$IOCTL" "/dev/pwm_led$ch" 0x0000754A -v $DIM 2>/dev/null
        done
        sleep 0.5
        for ch in 3 4 6 7; do
          "$IOCTL" "/dev/pwm_led$ch" 0x0000754A -v 0 2>/dev/null
        done
        sleep 0.5
      done
      for ch in 3 4 6 7; do
        "$IOCTL" "/dev/pwm_led$ch" 0x0000754A -v 0 2>/dev/null
      done
    ' sh "$SIGNAL_IOCTL" 2>/dev/null
}

hazards_stop() {
  systemctl stop "$HAZARDS_UNIT.service" 2>/dev/null
  [ -f /data/error-hazards.pid ] && kill "$(cat /data/error-hazards.pid)" 2>/dev/null
  rm -f /data/error-hazards.pid
  for signal_l in 3 4 6 7; do
    led_release "$signal_l"
  done
}

# Everything this file drives, dark, and the bar's state forgotten. For the
# start of a run: whatever a previous one left lit or breathing has nothing
# to say about this one, and a bar rendered on top of an old state file
# shows the old run's segments alongside the new run's first.
signal_all_off() {
  front_pulse_stop
  hazards_stop
  bootled_blink_stop
  bootled_guard_stop
  progress_off
  [ -n "$SIGNAL_I2CSET" ] && bootled off
  return 0
}

# --- the three things a caller actually wants -------------------------------

# An install is running on this vehicle. Idempotent, so every script that takes
# over mid-run can open with it.
signal_install_start() {
  bootled_init
  bootled amber
  bootled_guard_start
}

# It worked. The bar fades out and the LED goes dark, because the unlock that
# follows is the success signal and an LED the owner has to find and interpret
# is not.
signal_install_done() {
  front_pulse_stop
  bootled_guard_stop
  bootled_blink_stop
  progress_fade_off
  bootled off
}

# It did not. The bar means nothing any more, so it goes; the LED and the
# hazards are what is left, and both are stopped by
# /data/installer/stop-error-signals.sh when the installer reconnects.
signal_error() {
  front_pulse_stop
  progress_off
  bootled_guard_stop
  bootled_blink_red
  hazards_start
}

signal_error_stop() {
  bootled_blink_stop
  hazards_stop
}
