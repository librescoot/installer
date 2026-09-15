#!/bin/sh
# Librescoot DBC device control: SSH/SCP and dashboard power. Sourced, never
# run.
#
# The trampoline talks to the DBC before the MDB reboots, and the post-reboot
# phase talks to it again on the far side. Both need the same SSH retry logic
# and the same power switch, so one copy lives here rather than twice: once as
# a full function in the trampoline's own half and again as a shorter one
# inside the heredoc that generates the post-reboot half, which is how they
# drifted before (a wait_dbc_ssh call from the generated half found no
# definition until one was added there by hand).
#
# Sourcing is guarded everywhere ([ -f ] && .), so a run whose staging failed
# loses DBC control along with the install, rather than continuing half-blind.
# Every function here calls log(), which each caller defines for itself
# against its own log file, so nothing here hardcodes which file that is.

DBC_IP="192.168.7.2"

# A rapid laptop-to-DBC cable swap can leave the UDC continuously
# "configured": the DBC is another USB host and may enumerate the MDB before
# the disconnect debounce samples the gap. Rebinding g_ether is safe while the
# MDB remains a gadget and gives either host a clean enumeration. A responding
# DBC identifies the new peer; otherwise only a sustained unconfigured state
# completes the handoff.
USB_HANDOFF_UDC_STATE="${USB_HANDOFF_UDC_STATE:-/sys/class/udc/ci_hdrc.0/state}"
USB_HANDOFF_GONE_NEEDED="${USB_HANDOFF_GONE_NEEDED:-3}"
USB_HANDOFF_REBIND_AFTER="${USB_HANDOFF_REBIND_AFTER:-10}"
USB_HANDOFF_REBIND_RETRY="${USB_HANDOFF_REBIND_RETRY:-30}"
USB_HANDOFF_REBIND_GRACE="${USB_HANDOFF_REBIND_GRACE:-10}"

wait_for_laptop_disconnect() {
  local gone=0 configured=0 rebind_after="$USB_HANDOFF_REBIND_AFTER" grace=0
  while [ "$gone" -lt "$USB_HANDOFF_GONE_NEEDED" ]; do
    if ping -c 1 -W 1 "$DBC_IP" >/dev/null 2>&1; then
      log "DBC USB peer detected"
      return 0
    fi

    if grep -q configured "$USB_HANDOFF_UDC_STATE" 2>/dev/null; then
      gone=0
      grace=0
      configured=$((configured + 1))
      if [ "$configured" -ge "$rebind_after" ]; then
        log "  UDC stayed configured; rebinding the gadget to identify the peer"
        rmmod g_ether 2>/dev/null || true
        sleep 1
        modprobe g_ether 2>/dev/null || true
        sleep 2
        usb0_up
        configured=0
        rebind_after="$USB_HANDOFF_REBIND_RETRY"
        grace="$USB_HANDOFF_REBIND_GRACE"
      fi
    else
      configured=0
      if [ "$grace" -gt 0 ]; then
        grace=$((grace - 1))
      else
        gone=$((gone + 1))
      fi
    fi
    sleep 1
  done
  log "Laptop disconnected (debounced)"
}

# SSH/SCP to DBC with retries. -y -y makes dropbear skip host-key checking
# entirely. A flash gives the DBC a brand-new host key; the MDB still has the
# previous one in known_hosts, so a single -y (accept unknown, but ABORT on
# mismatch) still fails on a re-flash. -y -y is required to reach a freshly
# flashed DBC.
dbc_ssh() {
  local tries=0
  while [ $tries -lt 3 ]; do
    ssh -y -y root@$DBC_IP "$@" && return 0
    tries=$((tries + 1))
    log "  ssh retry $tries/3..."
    sleep 3
  done
  return 1
}

# Waits for SSH to answer, then requires it to keep answering for two more
# seconds before calling it stable: a DBC mid-reboot can accept one connection
# and drop the next, and code that acts on the first "ok" it sees can end up
# racing a board that is not actually up yet.
wait_dbc_ssh() {
  local timeout="${1:-90}" elapsed=0
  log "  waiting for DBC SSH (timeout ${timeout}s)..."
  while [ $elapsed -lt $timeout ]; do
    if ssh -y -y root@$DBC_IP 'echo ok' >/dev/null; then
      local stable=1
      sleep 1
      ssh -y -y root@$DBC_IP 'echo ok' >/dev/null && stable=$((stable+1))
      sleep 1
      ssh -y -y root@$DBC_IP 'echo ok' >/dev/null && stable=$((stable+1))
      if [ $stable -ge 3 ]; then
        log "  DBC SSH stable after ${elapsed}s"
        return 0
      fi
    fi
    elapsed=$((elapsed + 3))
    sleep 3
  done
  return 1
}

# Dashboard power, without lsc.
#
# lsc talks to vehicle-service, and neither is in the bootstrap image: it
# carries eleven packages and those are not among them. That matters because
# the whole point of staging this work early is to run it before the MDB has
# been rebooted into the full image.
#
# The line itself is gpiochip1 offset 18, global GPIO 50, which vehicle-service
# drives via libgpiod as "dashboard_power" (vehicle-service
# internal/hardware/constants.go). It is a request into the nRF52 rather than a
# rail we switch ourselves, so asserting it is all we have to do.
#
# lsc is still preferred when it exists. On the full image vehicle-service holds
# the line through libgpiod and a sysfs export would fail with EBUSY, so going
# around it there would be both rude and broken.
DBC_POWER_GPIO=50

DBC_CONTROL_DIR=/data/librescoot-installer/dbc-control
DBC_CONTROL_ACQUIRED=no

dbc_bootstrap_capable() {
  local artifact unit state
  artifact=$(mender-update show-artifact 2>/dev/null) || return 1
  [ "$artifact" = release-v1.3.0-minimal ] || return 1
  ! command -v lsc >/dev/null 2>&1 || return 1
  for unit in librescoot-vehicle.service vehicle-service.service; do
    state=$(systemctl show -p LoadState --value "$unit" 2>/dev/null) || return 1
    [ "$state" = not-found ] || return 1
  done
}

dbc_control_check() {
  local flag owner
  dbc_bootstrap_capable || return 1
  [ "$(cat "$DBC_CONTROL_DIR/owner" 2>/dev/null)" = "$RUN_ID" ] || return 1
  flag=$(redis-cli -h localhost --raw hget vehicle dbc-updating 2>/dev/null) || return 1
  case "$flag" in ''|false) ;; *) return 1 ;; esac
  owner=$(redis-cli -h localhost --raw hget ota heartbeat-owner:dbc 2>/dev/null) || return 1
  [ -z "$owner" ]
}

dbc_control_record() {
  [ "$(cat "$DBC_CONTROL_DIR/owner" 2>/dev/null)" = "$RUN_ID" ] || return 1
  printf '%s\n' "$1" > "$DBC_CONTROL_DIR/state.tmp" &&
    mv "$DBC_CONTROL_DIR/state.tmp" "$DBC_CONTROL_DIR/state" && sync
}

dbc_control_acquire() {
  dbc_bootstrap_capable || { log "ERROR: direct DBC install requires the supported bootstrap; owner-correlated full-image control is unavailable"; return 1; }
  if [ "$1" = outer ]; then
    mkdir -p "${DBC_CONTROL_DIR%/*}" || return 1
    mkdir "$DBC_CONTROL_DIR" 2>/dev/null || { log "ERROR: DBC control/recovery record exists; manual recovery required"; return 1; }
    printf '%s\n' "$RUN_ID" > "$DBC_CONTROL_DIR/owner" || return 1
    dbc_control_record acquired || return 1
  else
    [ "$(cat "$DBC_CONTROL_DIR/owner" 2>/dev/null)" = "$RUN_ID" ] || return 1
    [ "$(cat "$DBC_CONTROL_DIR/state" 2>/dev/null)" = handoff ] || return 1
    mkdir "$DBC_CONTROL_DIR/phase" 2>/dev/null || return 1
    dbc_control_record artifact-install || return 1
  fi
  dbc_control_check || return 1
  DBC_CONTROL_ACQUIRED=yes
  log "  Exclusive bootstrap DBC control verified"
}

dbc_control_release() {
  [ "$DBC_CONTROL_ACQUIRED" = yes ] || return 1
  [ "$(cat "$DBC_CONTROL_DIR/owner" 2>/dev/null)" = "$RUN_ID" ] || return 1
  case "$(cat "$DBC_CONTROL_DIR/state" 2>/dev/null)" in
    artifact-install-unknown|artifact-installed|mask-unknown|mask-prepared|activation-unknown|commit-unknown|ums-preparing) return 1 ;;
    committed) return 0 ;;
  esac
  rm -f "$DBC_CONTROL_DIR/owner" "$DBC_CONTROL_DIR/state"
  rmdir "$DBC_CONTROL_DIR/phase" 2>/dev/null || true
  rmdir "$DBC_CONTROL_DIR"
}

dbc_gpio_ready() {
  if [ -d "/sys/class/gpio/gpio$DBC_POWER_GPIO" ]; then
    [ "$(cat "/sys/class/gpio/gpio$DBC_POWER_GPIO/direction" 2>/dev/null)" = out ]
    return $?
  fi
  echo "$DBC_POWER_GPIO" > /sys/class/gpio/export 2>/dev/null || return 1
  sleep 1
  [ -d "/sys/class/gpio/gpio$DBC_POWER_GPIO" ] || return 1
  echo out > "/sys/class/gpio/gpio$DBC_POWER_GPIO/direction" 2>/dev/null || return 1
  [ "$(cat "/sys/class/gpio/gpio$DBC_POWER_GPIO/direction" 2>/dev/null)" = out ]
}

# $1: 1 to power the dashboard, 0 to cut it.
dbc_power_set() {
  if command -v lsc >/dev/null 2>&1; then
    local out
    if [ "$1" = "1" ]; then
      out=$(lsc --redis-addr localhost:6379 dbc on 2>&1) && { log "$out"; return 0; }
    else
      out=$(lsc --redis-addr localhost:6379 dbc off 2>&1) && { log "$out"; return 0; }
    fi
    log "  lsc dbc power failed; refusing GPIO fallback"
    return 1
  fi
  dbc_control_check || { log "  WARNING: refusing GPIO power control without bootstrap ownership"; return 1; }
  dbc_gpio_ready || { log "  WARNING: could not claim the dashboard power GPIO"; return 1; }
  echo "$1" > "/sys/class/gpio/gpio$DBC_POWER_GPIO/value" 2>/dev/null || return 1
  [ "$(cat "/sys/class/gpio/gpio$DBC_POWER_GPIO/value" 2>/dev/null)" = "$1" ]
}

# Power the dashboard on and hold until it answers SSH, or until the floor
# has passed. The request returns long before the board is up, and the very
# next thing every caller does is talk to it: a bootloader-config step that
# starts too early sees a refused connection and reports the board as gone,
# a UMS wait sees no device because U-Boot has not enumerated yet. Fifteen
# seconds is longer than a boot to SSH on either image, so a board that is
# not answering by then is a board the caller's own reachability check
# should judge, not one this needs to keep waiting on.
DBC_POWER_ON_SETTLE="${DBC_POWER_ON_SETTLE:-15}"

dbc_power_on() {
  dbc_power_set 1
  local rc=$? elapsed=0
  while [ "$elapsed" -lt "$DBC_POWER_ON_SETTLE" ]; do
    if ping -c 1 -W 1 "$DBC_IP" >/dev/null 2>&1 \
        && ssh -y -y root@$DBC_IP true >/dev/null 2>&1; then
      return "$rc"
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return "$rc"
}

# The rail does not drop the moment the request returns, and through
# vehicle-service it can lag further. A dashboard that never fully lost power
# does not come back in the bootloader, so it never enumerates as UMS and the
# wait for it times out against a board that simply never restarted. Hold a
# floor so the off is real before anything powers it on again.
DBC_POWER_OFF_SETTLE="${DBC_POWER_OFF_SETTLE:-5}"

dbc_power_off() {
  dbc_power_set 0
  local rc=$?
  sleep "$DBC_POWER_OFF_SETTLE"
  return "$rc"
}

# Cut power while an installer-owned DBC lifecycle is active. A normal off
# request is deliberately rejected in that state, so queue the explicit force
# command and verify that vehicle-service actually changed the power state.
dbc_power_off_force() {
  local out state elapsed=0
  command -v redis-cli >/dev/null 2>&1 || {
    log "  WARNING: redis-cli is unavailable for forced dashboard power-off"
    return 1
  }
  out=$(redis-cli -h localhost --raw lpush scooter:hardware dashboard:off:force 2>&1) || {
    log "  forced dashboard power-off request failed: $out"
    return 1
  }
  case "$out" in *[!0-9]*|'')
    log "  forced dashboard power-off was not queued: $out"
    return 1
  esac
  while [ "$elapsed" -lt 15 ]; do
    state=$(redis-cli -h localhost --raw hget vehicle dashboard:power 2>/dev/null)
    if [ "$state" = off ]; then
      log "  Dashboard power: off (forced and acknowledged)"
      sleep "$DBC_POWER_OFF_SETTLE"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  log "  forced dashboard power-off was not acknowledged (state=${state:-missing})"
  return 1
}

# Power the dashboard and wait for it to answer. Replaces lsc dbc on-wait,
# which additionally waits on dashboard[ready] in redis; a ping is the part
# that matters here and the part that works with no vehicle-service running.
# $1: seconds to wait, default 90.
dbc_power_on_wait() {
  local deadline="${1:-90}" elapsed=0
  dbc_power_on
  while [ "$elapsed" -lt "$deadline" ]; do
    ping -c 1 -W 2 "$DBC_IP" >/dev/null 2>&1 && return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Cut power and wait for it to actually go, so a following power-on is a real
# cycle rather than a no-op. Replaces lsc dbc off-wait.
dbc_power_off_wait() {
  local deadline="${1:-30}" elapsed=0
  # dbc_power_off already held the settle floor before this loop starts, so a
  # dashboard that stops answering immediately still had the rail down for it.
  dbc_power_off || return 1
  while [ "$elapsed" -lt "$deadline" ]; do
    if [ -n "${DBC_DEV:-}" ] && [ -b "$DBC_DEV" ]; then
      sleep 2
      elapsed=$((elapsed + 2))
      continue
    fi
    ping -c 1 -W 1 "$DBC_IP" >/dev/null 2>&1 || return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

dbc_power_off_wait_force() {
  local deadline="${1:-30}" elapsed=0
  dbc_power_off_force || return 1
  while [ "$elapsed" -lt "$deadline" ]; do
    ping -c 1 -W 1 "$DBC_IP" >/dev/null 2>&1 || return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}
