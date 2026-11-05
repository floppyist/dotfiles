#!/usr/bin/env bash
# Backlight (polybar ipc module, brightness keys and mouse wheel, with the on-screen bar)
# Usage: polybar-backlight.sh [up|down]   (no argument: print the current percentage)
#        polybar-backlight.sh up|down --wheel   the mouse wheel: 5 % per notch
#        polybar-backlight.sh --check     after a monitor change: the built-in panel comes back
#                                         on when it was off and is the only monitor now
#        polybar-backlight.sh --restore   at login: the built-in panel back on, if it was off
#
# A press moves 5 % (at least one level of the device: some have only 8 or 16) and glides there
# within 0.1 s; the capsule and the on-screen bar follow the glide. A held key repeats: X repeats
# keyboard keys 25 times a second, but the brightness keys of many laptops come from the firmware
# (ACPI "Video Bus"), which repeats after 0.5 s and then every 0.25 s. Each glide lasts until just
# after the next repeat is due, so holding a key is one smooth ramp, and the longer a slow key
# is held, the further each repeat goes (5, 10, 15, 20, then 25 %). A repeat is a press in the
# same direction within 0.33 s, at the pace of the one before (a person tapping is not that
# even) or after a pause like a key's first repeat (0.4 to 0.7 s). Three quick taps stay 5 % each.
# Devices with fewer than 100 levels, or that only brightnessctl may set, jump instead.
#
# 0 %: below the lowest step the built-in panel goes dark (black picture through its gamma, the
# backlight at its minimum), for a mirrored or second monitor. Only while another monitor is on:
# with the panel alone it stops at 5 %. Up brings it back; so does unplugging the other monitor
# (`displays` runs --check through `dotfiles apply --layout`) and logging in again (--restore).
set -u
# when the key came (first thing: repeats are told apart by their timing)
T0=${EPOCHREALTIME/[.,]/}
T0=$((10#$T0))

STEP=5              # percent per press
MIN=5               # the lowest step with the panel on
REPEAT_US=330000    # a press this soon after the last one (same direction) may repeat a held key
EVEN_US=50000       # ... if its interval is this close to the one before
TAP_US=100000       # a single press glides this long
FRAME_US=20000      # one glide step
FRAME=0.02
SHOW_US=40000       # the capsule and the on-screen bar follow the glide this often

SYS=${DOTFILES_SYSFS:-/sys}    # tests: a fake /sys
# The device dotfiles.conf `backlight` picked (`dotfiles apply`: firmware, then platform, then
# raw interface). Before the first apply: the same choice made here.
DF_BACKLIGHT_DEVICE="" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
if [[ -z $DF_BACKLIGHT_DEVICE && ${DF_BACKLIGHT:-auto} == auto ]]; then
    for want in firmware platform raw; do
        for d in "$SYS"/class/backlight/*; do
            t=""
            read -r t 2>/dev/null < "$d/type" && [[ $t == "$want" ]] && { DF_BACKLIGHT_DEVICE=${d##*/}; break 2; }
        done
    done
fi
SYSFS=$SYS/class/backlight/$DF_BACKLIGHT_DEVICE
[[ -n $DF_BACKLIGHT_DEVICE && $DF_BACKLIGHT_DEVICE != */* && -d $SYSFS ]] || { echo ""; exit 0; }

read -r CURR < "$SYSFS/brightness"
read -r MAX < "$SYSFS/max_brightness"
[[ $CURR =~ ^[0-9]{1,9}$ && $MAX =~ ^[0-9]{1,9}$ ]] && (( MAX > 0 )) || { echo ""; exit 0; }
# the level of the lowest step (0 is off on many devices)
LOW=$(( (MIN * MAX + 50) / 100 ))
(( LOW < 1 )) && LOW=1

# The panel is off: "PERCENT OUTPUT" (the brightness before, the xrandr output). In the state
# directory, not the runtime one: the backlight stays low across logins, the gamma does not.
OFF_FILE=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backlight-off

percent() { P=$(( ($1 * 100 + MAX / 2) / MAX )); }
now_us() { local t=${EPOCHREALTIME/[.,]/}; NOW=$((10#$t)); }

# Direct write needs the udev rule (group video); else brightnessctl (logind), for this device
write_raw() {
    { echo "$1" > "$SYSFS/brightness"; } 2>/dev/null ||
        brightnessctl -q -d "$DF_BACKLIGHT_DEVICE" set "$1" >/dev/null 2>&1
}

# The capsule and the on-screen bar for level $1, "off" while the panel is dark. In the
# background (callers `wait` where the order matters); the lock descriptors stay here.
show() {
    local text summary value
    if [[ -e $OFF_FILE ]]; then
        text="%{F$DF_MUTED}off%{F-}" summary="󰃠  Display off" value=0
    else
        percent "$1"
        value=$P text="$P%" summary="󰃠  Brightness  $P%"
    fi
    polybar-msg action "#backlight.send.$text" >/dev/null 2>&1 8>&- 9>&- &
    notify-send -a osd -u low -h string:x-dunst-stack-tag:brightness -h "int:value:$value" \
        "$summary" >/dev/null 2>&1 8>&- 9>&- &
}

# The built-in panel's xrandr output (eDP, LVDS, DSI) -> PANEL; OTHERS: other monitors are on
panel_outputs() {
    local name rest
    PANEL="" OTHERS=0
    [[ -n ${DISPLAY-} ]] && command -v xrandr >/dev/null || return 1
    while read -r name rest; do
        [[ $rest == connected* && $name =~ ^(eDP|LVDS|DSI) && -z $PANEL ]] && PANEL=$name
    done < <(xrandr --current 2>/dev/null)
    [[ -n $PANEL ]] || return 1
    # RandR monitors in use ("0: +*eDP 1920/309x1080/174+0+0  eDP"); a mirror counts too
    while read -r _ _ _ name; do
        [[ -n $name && $name != "$PANEL" ]] && OTHERS=1
    done < <(xrandr --listactivemonitors 2>/dev/null | tail -n +2)
    return 0
}

panel_on() {
    local out=""
    read -r _ out 2>/dev/null < "$OFF_FILE"
    [[ $out =~ ^[A-Za-z0-9-]+$ ]] || { panel_outputs; out=$PANEL; }
    [[ -n $out && -n ${DISPLAY-} ]] && xrandr --output "$out" --brightness 1 >/dev/null 2>&1
    rm -f "$OFF_FILE"
}

# A private directory for the state and the locks -> RUN
private_run() {
    if [[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]]; then
        RUN=$XDG_RUNTIME_DIR
    else
        RUN=${XDG_CACHE_HOME:-$HOME/.cache}/backlight
        mkdir -p -m 700 "$RUN" 2>/dev/null && [[ -O $RUN ]] || return 1
    fi
    STATE=$RUN/backlight.state
}

# The last press: "TARGET_LEVEL TIME_US DIRECTION GLIDE_END_US REPEATS INTERVAL_US"
read_state() {
    local tg="" t="" d="" u="" n="" i=""
    read -r tg t d u n i 2>/dev/null < "$STATE"
    if [[ $tg =~ ^[0-9]{1,9}$ && $t =~ ^[0-9]{1,18}$ && $u =~ ^[0-9]{1,18}$ && $n =~ ^[0-9]{1,4}$ &&
          $i =~ ^[0-9]{1,9}$ ]] && (( tg <= MAX )); then
        TARGET=$tg PRESSED=$t DIR=$d UNTIL=$u REPEATS=$n INTERVAL=$i
    else
        TARGET="" PRESSED=0 DIR="" UNTIL=0 REPEATS=0 INTERVAL=0
    fi
}

# Glides to the target of the last press, so that it arrives at the press's glide end, and
# shows the way. One glide at a time; it takes up new targets while it runs.
animate() {
    local sfd cur prev=-1 frames move shown=0 n=0
    exec 8>>"$RUN/backlight-anim.lock"
    flock -n 8 || return 0
    # a read that never gets data: sleeps without starting a process per frame
    exec {sfd}<> <(:)
    while (( n++ < 500 )); do      # (10 s at most)
        read_state
        [[ -n $TARGET ]] || break
        read -r cur < "$SYSFS/brightness" || break
        [[ $cur =~ ^[0-9]{1,9}$ ]] || break
        # there, or the last write did not take (no permission any more)
        (( cur == TARGET || cur == prev )) && break
        prev=$cur
        now_us
        frames=$(( (UNTIL - NOW) / FRAME_US ))
        (( frames < 1 )) && frames=1
        # the rest of the way in equal steps until the end time
        move=$(( (TARGET - cur) / frames ))
        (( move == 0 )) && move=$(( TARGET > cur ? 1 : -1 ))
        write_raw $(( cur + move ))
        if (( NOW - shown >= SHOW_US )); then
            show $(( cur + move ))
            shown=$NOW
        fi
        read -r -t "$FRAME" -u "$sfd" _
    done
    exec {sfd}<&-
    # the final value last: after the ones still on their way
    wait
    read -r cur < "$SYSFS/brightness" && show "$cur" && wait
    exec 8>&-
    # a press that came while this glide was ending found the lock taken: go on for it
    read_state
    [[ -n $TARGET ]] && read -r cur < "$SYSFS/brightness" && (( cur != TARGET && cur != prev )) && animate
    return 0
}

press() {
    local dir=$1 base dt=-1 n=0 step=$STEP speed dur=$TAP_US new p
    exec 9>>"$RUN/backlight.lock"
    flock 9
    read_state
    # (read again: this press may have waited for the one before)
    read -r CURR < "$SYSFS/brightness"
    [[ $CURR =~ ^[0-9]{1,9}$ ]] || return 0
    # from the target of the last press while it is fresh (else from the real value: another
    # program may have changed it since)
    base=$CURR
    [[ -n $TARGET ]] && (( T0 - PRESSED < 1000000 )) && base=$TARGET
    [[ $DIR == "$dir" ]] && (( T0 > PRESSED )) && dt=$(( T0 - PRESSED ))
    if [[ -z ${WHEEL-} ]] && (( dt >= 0 && dt <= REPEAT_US )); then
        n=1
        if (( REPEATS )); then
            (( (dt > INTERVAL ? dt - INTERVAL : INTERVAL - dt) <= EVEN_US )) && n=$(( REPEATS + 1 ))
        elif (( INTERVAL >= 400000 && INTERVAL <= 700000 )); then
            n=3
        fi
    fi
    if (( n >= 2 )); then
        # a held key: percent per second 20, 40, 60, 80, then 100, times its interval, 5 % steps
        speed=$(( n >= 6 ? 100 : 20 * (n - 1) ))
        step=$(( (speed * dt / 100000 + 25) / 50 * 5 ))
        (( step < STEP )) && step=$STEP
        (( step > 25 )) && step=25
    fi
    if (( dt >= 0 && dt < 700000 )); then
        # until just after the next press would come (this bridges the firmware's first pause too)
        dur=$(( dt * 5 / 4 ))
        (( dur < 40000 )) && dur=40000
        (( dur > 300000 )) && dur=300000
    fi
    percent "$base"
    p=$P
    if [[ $dir == up ]]; then
        if [[ -e $OFF_FILE ]]; then
            panel_on
            new=$LOW
        else
            p=$(( (p + step) / 5 * 5 ))
            (( p > 100 )) && p=100
            new=$(( (p * MAX + 50) / 100 ))
            (( new <= base )) && new=$(( base + 1 ))
            (( new > MAX )) && new=$MAX
        fi
    elif [[ -e $OFF_FILE ]]; then
        # off already: stays off while another monitor is on (else the panel comes back)
        if panel_outputs && (( OTHERS )); then
            new=0 dur=150000
        else
            panel_on
            new=$LOW
        fi
    elif (( base <= LOW )) && panel_outputs && (( OTHERS )); then
        # below the lowest step: the panel off, while another monitor shows the desktop
        mkdir -p "${OFF_FILE%/*}"
        printf '%s %s\n' "$p" "$PANEL" > "$OFF_FILE"
        xrandr --output "$PANEL" --brightness 0 >/dev/null 2>&1
        new=0 dur=150000
    else
        p=$(( (p - step + 4) / 5 * 5 ))
        new=$(( (p * MAX + 50) / 100 ))
        (( new >= base )) && new=$(( base - 1 ))
        (( new < LOW )) && new=$LOW
        (( new > base )) && new=$base
    fi
    (( dt >= 0 && dt < 10000000 )) || dt=0
    printf '%s %s %s %s %s %s\n' "$new" "$T0" "$dir" $(( T0 + dur )) "$n" "$dt" > "$STATE"
    if (( GLIDE )); then
        # the glide outlives this press (with one running already, it takes up the new target)
        animate 9>&- </dev/null >/dev/null 2>&1 &
    else
        write_raw "$new"
        show "$new"
        wait
    fi
}

case "${1:-}" in
    up|down)
        [[ ${2-} == --wheel ]] && WHEEL=1
        private_run || exit 1
        # gliding needs many fine levels and a direct write
        GLIDE=0
        (( MAX >= 100 )) && [[ -w $SYSFS/brightness ]] && GLIDE=1
        press "$1"
        ;;
    --check|--restore)
        [[ -e $OFF_FILE ]] || exit 0
        if [[ $1 == --check ]]; then
            panel_outputs || exit 0
            (( OTHERS )) && exit 0
        fi
        read -r was _ 2>/dev/null < "$OFF_FILE"
        [[ ${was-} =~ ^[0-9]{1,3}$ ]] && (( was >= MIN && was <= 100 )) || was=$MIN
        panel_on
        new=$(( (was * MAX + 50) / 100 ))
        (( new < LOW )) && new=$LOW
        write_raw "$new"
        private_run && rm -f "$STATE"
        polybar-msg action "#backlight.send.$was%" >/dev/null 2>&1
        ;;
    *)
        percent "$CURR"
        if [[ -e $OFF_FILE ]]; then echo "%{F$DF_MUTED}off%{F-}"; else echo "$P%"; fi
        ;;
esac
