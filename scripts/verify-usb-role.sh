#!/bin/sh
# Verify that the MDB's dual-role USB controller can be flipped host <-> gadget
# at runtime, and how long each direction takes.
#
# The dashboard flash currently reboots the MDB to get back to gadget mode: the
# happy path switches to host for the UMS write and then relies on a normal
# boot coming back as a gadget. A runtime restore already exists in the
# trampoline (restore_gadget) but only runs on failure paths. If the flip is
# reliable both ways, the reboot can go, which also closes the window where
# every light on the scooter is dark.
#
# Flipping to host drops usb0, and with it the SSH session that started this,
# so the script detaches itself into its own systemd scope. setsid alone does
# not escape the invoking service's cgroup.
#
#   scp scripts/verify-usb-role.sh root@192.168.7.1:/data/
#   ssh root@192.168.7.1 'sh /data/verify-usb-role.sh'
#   # link drops and comes back, then:
#   ssh root@192.168.7.1 'cat /data/usb-role-verify.log'
#
# Every exit path ends in gadget mode. If the restore cannot be made to work,
# the script reboots rather than leaving the board unreachable from either the
# laptop or the dashboard.

set -u

CYCLES="${CYCLES:-5}"
RESULT="${RESULT:-/data/usb-role-verify.log}"
UNIT="librescoot-usb-role-verify"
# Long enough for CYCLES slow cycles, short enough that a wedged run recovers
# on its own while the user is still standing there.
DEADLINE="${DEADLINE:-600}"

USB_IP=192.168.7.1
UDC_STATE=/sys/class/udc/ci_hdrc.0/state

log() { echo "$(date '+%H:%M:%S') $*" >> "$RESULT"; }

find_role_path() {
    for p in /sys/kernel/debug/ci_hdrc.0/role \
             /sys/kernel/debug/usb/ci_hdrc.0/role \
             /sys/bus/platform/devices/ci_hdrc.0/role; do
        [ -e "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# --- detach ------------------------------------------------------------------
# Re-exec under systemd so the run outlives the SSH session that flipping to
# host is about to kill.
if [ "${USB_ROLE_VERIFY_CHILD:-}" != "1" ]; then
    : > "$RESULT"
    log "verifier starting, cycles=$CYCLES deadline=${DEADLINE}s"
    if ! ROLE_PATH="$(find_role_path)"; then
        log "FATAL: no role attribute found, is debugfs mounted?"
        echo "no role attribute; see $RESULT" >&2
        exit 1
    fi
    log "role attribute: $ROLE_PATH"
    systemctl stop "${UNIT}.service" 2>/dev/null
    systemd-run --unit="$UNIT" --collect --quiet --slice=system.slice \
        --property=RuntimeMaxSec="$DEADLINE" \
        --setenv=USB_ROLE_VERIFY_CHILD=1 \
        --setenv=CYCLES="$CYCLES" \
        --setenv=RESULT="$RESULT" \
        /bin/sh "$0"
    echo "detached as $UNIT; read $RESULT once usb0 is back"
    exit 0
fi

ROLE_PATH="$(find_role_path)" || { log "FATAL: role attribute vanished"; exit 1; }

role_now() { cat "$ROLE_PATH" 2>/dev/null; }

role_write() {
    # The write blocks while the controller settles, and has been seen to hang
    # outright; the timeout is what keeps a wedged controller from taking the
    # deadline with it.
    timeout 15 sh -c "echo $1 > $ROLE_PATH" 2>/dev/null
}

usb0_up() {
    ip addr show usb0 2>/dev/null | grep -q "$USB_IP" \
        || ifconfig usb0 2>/dev/null | grep -q "$USB_IP"
}

now_ms() {
    # /proc/uptime rather than date +%s%N: busybox date has no nanoseconds.
    awk '{printf "%d", $1 * 1000}' /proc/uptime
}

to_host() {
    rmmod g_ether 2>/dev/null
    role_write host || return 1
    [ "$(role_now)" = "host" ]
}

to_gadget() {
    attempt=0
    while [ $attempt -lt 3 ]; do
        attempt=$((attempt + 1))
        rmmod g_ether 2>/dev/null
        role_write gadget || true
        modprobe g_ether 2>/dev/null
        ifconfig usb0 "$USB_IP" netmask 255.255.255.0 up 2>/dev/null
        waited=0
        while [ $waited -lt 10 ]; do
            if [ "$(role_now)" = "gadget" ] && usb0_up; then
                [ $attempt -gt 1 ] && log "    (gadget took $attempt attempts)"
                return 0
            fi
            sleep 1
            waited=$((waited + 1))
        done
        log "    gadget attempt $attempt failed (role=$(role_now))"
    done
    return 1
}

# --- the run -----------------------------------------------------------------
log "start role=$(role_now) usb0=$(usb0_up && echo up || echo down)"

pass=0
fail=0
cycle=0
while [ $cycle -lt "$CYCLES" ]; do
    cycle=$((cycle + 1))

    t0="$(now_ms)"
    if to_host; then
        t_host=$(( $(now_ms) - t0 ))
        log "cycle $cycle: -> host   OK   ${t_host}ms"
    else
        t_host=$(( $(now_ms) - t0 ))
        log "cycle $cycle: -> host   FAIL ${t_host}ms (role=$(role_now))"
        fail=$((fail + 1))
        to_gadget || true
        continue
    fi

    t0="$(now_ms)"
    if to_gadget; then
        t_gadget=$(( $(now_ms) - t0 ))
        log "cycle $cycle: -> gadget OK   ${t_gadget}ms udc=$(cat $UDC_STATE 2>/dev/null)"
        pass=$((pass + 1))
    else
        t_gadget=$(( $(now_ms) - t0 ))
        log "cycle $cycle: -> gadget FAIL ${t_gadget}ms (role=$(role_now))"
        fail=$((fail + 1))
    fi
done

# --- land in gadget mode, whatever happened ----------------------------------
if [ "$(role_now)" != "gadget" ] || ! usb0_up; then
    log "final restore needed"
    if ! to_gadget; then
        log "VERDICT: gadget unrecoverable, rebooting to get the board back"
        sync
        reboot &
        sleep 20
        reboot -f
        exit 1
    fi
fi

log "final role=$(role_now) usb0=$(usb0_up && echo up || echo down) udc=$(cat $UDC_STATE 2>/dev/null)"
log "VERDICT: $pass/$CYCLES cycles clean, $fail failure(s)"
if [ "$fail" -eq 0 ]; then
    log "the flash can drop its reboot: the runtime flip works both ways"
else
    log "keep the reboot, or defer it to the end of the dashboard work"
fi
