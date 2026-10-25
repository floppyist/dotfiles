#!/usr/bin/env bash
# Desktop notification for new mail. Called by neomutt via new_mail_command.
# Usage: mail-notify.sh NEW UNREAD FOLDER
set -u

new=${1:-0}
unread=${2:-0}
folder=${3:-INBOX}

notify-send -a "Mutt" -u normal "New mail" "$new new, $unread unread in ${folder##*/}" >/dev/null 2>&1
