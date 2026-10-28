# shellcheck shell=bash
# Shared by the polybar module scripts (sourced, not run; install.sh does not link this
# directory into ~/.local/bin).
#
# Text that other people control (SSIDs, Bluetooth device names, VPN profile names from
# imported files, track titles from websites) must go through polybar_safe: polybar parses
# %{...} tags in script output, including click actions that run commands. Control
# characters are dropped as well. Replacement strings are quoted: since bash 5.2 an unquoted
# & in them means "the match".
polybar_safe() { local s=${1//[[:cntrl:]]/} pat='%{' rep='% {'; printf '%s' "${s//"$pat"/"$rep"}"; }

# Truncate to N characters (polybar's label-maxlen would also count and cut %{...} tags)
truncate() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }
