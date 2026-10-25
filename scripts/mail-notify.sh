#!/usr/bin/env bash
# Desktop notification for new mail. Called by neomutt via new_mail_command.
# Usage: mail-notify.sh NEW UNREAD
# Only numbers are passed in: folder names come from the mail server and would end up
# inside a shell command line (neomutt runs new_mail_command through sh).
set -u

new=${1:-0}
unread=${2:-0}
[[ "$new" =~ ^[0-9]+$ ]] || new=0
[[ "$unread" =~ ^[0-9]+$ ]] || unread=0

if (( new == 1 )); then
    summary="1 new message"
else
    summary="$new new messages"
fi

notify-send -a mail "$summary" "$unread unread in total" >/dev/null 2>&1
