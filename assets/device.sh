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

dbc_gpio_ready() {
  [ -d "/sys/class/gpio/gpio$DBC_POWER_GPIO" ] && return 0
  echo "$DBC_POWER_GPIO" > /sys/class/gpio/export 2>/dev/null || true
  sleep 1
  [ -d "/sys/class/gpio/gpio$DBC_POWER_GPIO" ] || return 1
  echo out > "/sys/class/gpio/gpio$DBC_POWER_GPIO/direction" 2>/dev/null || true
  return 0
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
    log "  lsc dbc power failed, falling back to the GPIO"
  fi
  dbc_gpio_ready || { log "  WARNING: could not claim the dashboard power GPIO"; return 1; }
  echo "$1" > "/sys/class/gpio/gpio$DBC_POWER_GPIO/value" 2>/dev/null
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
  dbc_power_off
  while [ "$elapsed" -lt "$deadline" ]; do
    ping -c 1 -W 1 "$DBC_IP" >/dev/null 2>&1 || return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}
