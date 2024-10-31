#!/usr/bin/env bash

#########################
# i3-focuser
#
# Licence: GNU GPLv3
# Author: Tomasz Kapias
#
# Dependencies:
#   i3wm
#   i3-msg
#   bash
#   bonk https://github.com/FascinatedBox/bonk
#   systemctl
#   renice
#   setsid
#
#########################

shopt -s extglob

# locale
export LC_ALL="C.UTF-8"
export TZ=:/etc/localtime

Help() {
	cat <<-'HEREDOC'
		i3-focuser will try to focus, hide or close a floating window
		using x11 and i3wm's scratchpad.
		Otherwise it will run a systemd service or/and a command.

		Usage:
		  ./i3-focuser.bash [-h] [Options...] [-c 'pattern' [-n 'pattern']] [-m command [-s service]]
		options:
		  -h              Print this Help.
		  -c "<WM_CLASS>" Regex pattern matching window general class.
		  -n "<WM_NAME>"  Regex pattern matching window name (or title).
		  -m "<command>"  Command with arguments to run if there is no match.
		  -s "<service>"  Systemd service to check/start in priority if there is no match.
		  -i              Use i3wm scratchpad to hide the match instead of a gracefull quit.
		  -v              Match only visible windows. Can help with sorting matches.

		Mandatory match:  -c and/or -n
		Mandatory run:    -m and/or -s

	HEREDOC
}

# check required command(s)
# usage: check_command cmd1 cmd2
check_command() {
	local error notfound joined
	error=0
	local -a commands
	read -r -a commands <<<"$*"
	for cmd in "${commands[@]}"; do
		if ! command -v "$cmd" 1>/dev/null; then
			((error += 1))
			notfound+=$(/usr/bin/printf "\n  - '%s' not found" "$cmd")
		fi
	done
	if [[ ! "$error" == "0" ]]; then
		/usr/bin/printf -v joined '%s,' "${commands[@]}"
		/usr/bin/printf '\033[1;37mRequired Commands\033[0m:\n  %s' "${joined%,}"
		/usr/bin/printf '\n\n\033[1;31m%s Error 127 occured\033[0m:' "$error"
		/usr/bin/printf '%s\n' "$notfound"
		return 127
	fi
}

check_command i3 i3-msg bonk systemctl renice setsid || exit $?

declare -a i3msg_cmd bonk_cmd bonk_select_cmd systemctl_cmd user_command
i3msg_cmd=("i3-msg")
bonk_cmd=("bonk")
bonk_select_cmd=("${bonk_cmd[@]}" "select" "--all")
systemctl_cmd=("systemctl" "--user" "--quiet")
declare scratchpad class_pattern name_pattern user_service \
	mandatory_err win_focused win_match

while getopts ":hc:n:m:s:iv" option; do
	case $option in
	h)
		Help
		exit 0
		;;
	c) class_pattern="${OPTARG}" ;;
	n) name_pattern="${OPTARG}" ;;
	m) read -r -a user_command <<<"${OPTARG}" ;;
	s) user_service="${OPTARG}" ;;
	i) scratchpad=1 ;;
	v) bonk_select_cmd=("${array[@]/--all/}") ;;
	\?)
		/usr/bin/printf '\nUnknown option: -%s\n\n' "$OPTARG" >&2
		Help
		exit 1
		;;
	:)
		/usr/bin/printf '\nMissing argument for -%s\n\n' "$OPTARG" >&2
		Help
		exit 1
		;;
	*)
		/usr/bin/printf '\nUnimplemented option: -%s\n\n' "$option" >&2
		Help
		exit 1
		;;
	esac
done

# mandatory options
if [[ -z "$class_pattern" ]] && [[ -z "$name_pattern" ]]; then
	mandatory_err+=$(/usr/bin/printf '\n  - "-c" or/and "-n"')
fi
if ((${#user_command[@]} == 0)) && [[ -z "$user_service" ]]; then
	mandatory_err+=$(/usr/bin/printf '\n  - "-m" or/and "-s"')
fi
if [[ -n "$mandatory_err" ]]; then
	/usr/bin/printf '\033[1;31mError!\033[0m Mandatory options are missing:'
	/usr/bin/printf '%s\n' "${mandatory_err}"
	/usr/bin/printf '\n'
	Help
	exit 1
fi

# help to lower the risk of concurrencies
/usr/bin/renice -n 10 $$

# focused windows id
win_focused=$("${bonk_select_cmd[@]}" get-active 2>/dev/null)

# list matching windows and select last matching id
sleep 0.1
if [[ -z "$class_pattern" ]]; then
	bonk_select_cmd+=("--title" "${name_pattern}")
elif [[ -z "$name_pattern" ]]; then
	bonk_select_cmd+=("--class" "${class_pattern}")
else
	bonk_select_cmd+=("--class" "${class_pattern}" "--title" "${name_pattern}")
fi
win_match=$("${bonk_select_cmd[@]}" 2>/dev/null | tail -1)

# match is focused
if [[ "${win_focused=:-0}" == "${win_match:-1}" ]]; then
	if [[ -n "$scratchpad" ]]; then
		"${i3msg_cmd[@]}" -q "[id=${win_match}]" move scratchpad
	else
		"${bonk_cmd[@]}" close -w "$win_match" 2>/dev/null
	fi
# match is somewhere
elif [[ -n "$win_match" ]]; then
	"${i3msg_cmd[@]}" -q "[id=${win_match}]" move to workspace current, focus
	sleep 0.1
	if [[ ! "$win_match" == "$("${bonk_cmd[@]}" get-active 2>/dev/null)" ]]; then
		/usr/bin/setsid --fork "${user_command[@]}" >&/dev/null </dev/null &
	fi
# no match but a service to check
elif [[ -n "$user_service" ]]; then
	if ! "${systemctl_cmd[@]}" is-active "$user_service"; then
		"${systemctl_cmd[@]}" --wait start "$user_service"
	fi
	if ((${#user_command[@]} != 0)); then
		/usr/bin/setsid --fork "${user_command[@]}" >&/dev/null </dev/null &
	fi
# no match, no service
else
	/usr/bin/setsid --fork "${user_command[@]}" >&/dev/null </dev/null &
fi
