# shellcheck shell=bash
# Shared by volume.sh (keys, mouse wheel) and polybar-volume.sh (the capsule). Sourced.

# The capsule text for volume $1 (percent) and mute state $2 (yes/no) -> stdout
volume_text() {
    local vol=$1 icon
    if [[ $2 == yes ]]; then
        printf '%%{F%s}󰝟  mute%%{F-}\n' "${DF_MUTED:-#7c6f64}"
        return
    fi
    if (( vol >= 66 )); then icon=󰕾; elif (( vol >= 33 )); then icon=󰖀; else icon=󰕿; fi
    printf '%%{F%s}%s  %%{F-}%s%%\n' "${DF_BLUE_HI:-#83a598}" "$icon" "$vol"
}

# Volume of the default output (the loudest channel) and its mute state -> VOL, MUTE (yes/no).
# Both pactl calls run at the same time (each one connects to the server: ~15 ms).
volume_read() {
    local out pct mute="" fd
    VOL=-1 MUTE=no
    exec {fd}< <(LC_ALL=C pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null)
    out=$(LC_ALL=C pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null)
    read -r -u "$fd" mute
    exec {fd}<&-
    [[ $mute == *yes* ]] && MUTE=yes
    for pct in $(grep -o '[0-9]\+%' <<< "$out"); do
        pct=${pct%\%}
        (( 10#$pct > VOL )) && VOL=$(( 10#$pct ))
    done
    (( VOL >= 0 ))
}

# A private directory for runtime files -> RUN ($XDG_RUNTIME_DIR if it is ours, else ~/.cache/$1)
private_run() {
    if [[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]]; then
        RUN=$XDG_RUNTIME_DIR
    else
        RUN=${XDG_CACHE_HOME:-$HOME/.cache}/$1
        mkdir -p -m 700 "$RUN" || return 1
    fi
}
