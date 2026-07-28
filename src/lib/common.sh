#!/bin/bash

# common.sh: Set variables and functions used across Linxira Update stages
# https://github.com/Antiz96/arch-update
# SPDX-License-Identifier: GPL-3.0-or-later

# Display debug traces if the -D / --debug argument is passed
for arg in "${@}"; do
	case "${arg}" in
		-D|--debug)
			set -x
		;;
	esac
done

# Reset the option var if it is equal to -D / --debug (to avoid false negative "invalid option" error)
# shellcheck disable=SC2154
case "${option}" in
	-D|--debug)
		unset option
	;;
esac

# Create state and tmp dirs if they don't exist
# shellcheck disable=SC2154
statedir="${XDG_STATE_HOME:-${HOME}/.local/state}/${name}"
tmpdir="${TMPDIR:-/tmp}/${name}-${UID}"
mkdir -p "${statedir}" "${tmpdir}" || exit 16

# Define checkupdates temporary db dir prefix
# shellcheck disable=SC2034
checkupdates_db_tmpdir_prefix="${tmpdir}/checkupdates-"

# Declare necessary parameters for translations
# shellcheck disable=SC1091
. gettext.sh
# shellcheck disable=SC2154
export TEXTDOMAIN="${text_domain}"
# Check where the translation files are installed (depending on the PREFIX used during the installation) to see if the default TEXTDOMAINDIR path (/usr/share/locale) should be superseded
if [ -f "${XDG_DATA_HOME}/locale/fr/LC_MESSAGES/${text_domain}.mo" ]; then
	export TEXTDOMAINDIR="${XDG_DATA_HOME}/locale"
elif [ -f "${HOME}/.local/share/locale/fr/LC_MESSAGES/${text_domain}.mo" ]; then
	export TEXTDOMAINDIR="${HOME}/.local/share/locale"
elif [ -f "${XDG_DATA_DIRS}/locale/fr/LC_MESSAGES/${text_domain}.mo" ]; then
	export TEXTDOMAINDIR="${XDG_DATA_DIRS}/locale"
elif [ -f "/usr/local/share/locale/fr/LC_MESSAGES/${text_domain}.mo" ]; then
	export TEXTDOMAINDIR="/usr/local/share/locale"
fi

# Definition of the colors for the colorized output
if [ -z "${no_color}" ]; then
	bold="\e[1m"
	blue="${bold}\e[34m"
	green="${bold}\e[32m"
	yellow="${bold}\e[33m"
	red="${bold}\e[31m"
	color_off="\e[0m"
	# shellcheck disable=SC2034
	pacman_color_opt="always"
else
	# shellcheck disable=SC2034
	pacman_color_opt="never"
	contrib_color_opt+=("--nocolor")
fi

# Definition of the main_msg function: Display a message as a main message
main_msg() {
	msg="${1}"
	echo -e "${blue}==>${color_off}${bold} ${msg}${color_off}"
}

# Definition of the info_msg function: Display a message as an information message
info_msg() {
	msg="${1}"
	echo -e "${green}==>${color_off}${bold} ${msg}${color_off}"
}

# Definition of the ask_msg function: Display a message as an interactive question
ask_msg() {
	msg="${1}"
	# shellcheck disable=SC2034
	read -rp $"$(echo -e "${blue}->${color_off}${bold} ${msg}${color_off} ")" answer
}

# Definition of the ask_msg_array function: Display a message as an interactive question with multiple possible answers 
ask_msg_array() {
	msg="${1}"
	# shellcheck disable=SC2034
	read -rp $"$(echo -e "${blue}->${color_off}${bold} ${msg}${color_off} ")" -a answer_array
}

# Definition of the warning_msg function: Display a message as a warning message
warning_msg() {
	msg="${1}"
	echo -e "${yellow}==> $(eval_gettext "WARNING"):${color_off}${bold} ${msg}${color_off}"
}

# Definition of the error_msg function: Display a message as an error message
error_msg() {
	msg="${1}"
	echo -e >&2 "${red}==> $(eval_gettext "ERROR"):${color_off}${bold} ${msg}${color_off}"
}

# Definition of the continue_msg function: Display the continue message
continue_msg() {
	msg="$(eval_gettext "Press \"enter\" to continue ")"
	read -n 1 -r -s -p $"$(info_msg "${msg}")" && echo
}

# Definition of the quit_msg function: Display the quit message
quit_msg() {
	msg="$(eval_gettext "Press \"enter\" to quit ")"
	read -n 1 -r -s -p $"$(info_msg "${msg}")" && echo
}

# Definition of the AUR helper to use (depending on if / which one is installed on the system and if it's not already defined in arch-update.conf) for the optional AUR packages support
check_aur_helper() {
	if [ -z "${no_aur}" ]; then
		# shellcheck disable=SC2034
		if [ -z "${aur_helper}" ]; then
			if command -v paru > /dev/null; then
				# shellcheck disable=SC2034
				aur_helper="paru"
			elif command -v yay > /dev/null; then
				# shellcheck disable=SC2034
				aur_helper="yay"
			elif command -v pikaur > /dev/null; then
				# shellcheck disable=SC2034
				aur_helper="pikaur"
			fi
		else
			if ! command -v "${aur_helper}" > /dev/null; then
				warning_msg "$(eval_gettext "The \${aur_helper} AUR helper set for AUR packages support in the \${name}.conf configuration file is not found\n")"
				unset aur_helper
			fi
		fi
	fi
}

# Check if flatpak is installed for the optional Flatpak support
if [ -z "${no_flatpak}" ]; then
	# shellcheck disable=SC2034
	flatpak_support=$(command -v flatpak)
	# Disable flatpak support if flatpak is available but no Flatpak package is installed
	if [ -n "${flatpak_support}" ]; then
		flatpak_user_packages=$(timeout --foreground --kill-after=5s "${update_check_timeout}" flatpak list --user)
		flatpak_user_exit_code=$?
		flatpak_system_packages=$(timeout --foreground --kill-after=5s "${update_check_timeout}" flatpak list --system)
		flatpak_system_exit_code=$?
		if [ "${flatpak_user_exit_code}" -ne 0 ] || [ "${flatpak_system_exit_code}" -ne 0 ]; then
			flatpak_detection_failed="true"
		fi
		if [ "${flatpak_user_exit_code}" -eq 0 ] && [ "${flatpak_system_exit_code}" -eq 0 ] \
			&& [ -z "${flatpak_user_packages}${flatpak_system_packages}" ]; then
			unset flatpak_support
		fi
	fi
fi

# Check if notify-send is installed for the optional desktop notification support
if [ -z "${no_notification}" ]; then
	# shellcheck disable=SC2034
	notification_support=$(command -v notify-send)
fi

# Definition of the elevation command to use (depending on which one is installed on the system and if it's not already defined in arch-update.conf)
check_su_cmd () {
	if [ -z "${su_cmd}" ]; then
		if command -v sudo > /dev/null; then
			su_cmd="sudo"
		elif command -v sudo-rs > /dev/null; then
			su_cmd="sudo-rs"
		elif command -v doas > /dev/null; then
			su_cmd="doas"
		elif command -v run0 > /dev/null; then
			su_cmd="run0"
		else
			error_msg "$(eval_gettext "A privilege elevation command is required (sudo, sudo-rs, doas or run0)\n")" && quit_msg
			exit 2
		fi
	else
		if ! command -v "${su_cmd}" > /dev/null; then
			error_msg "$(eval_gettext "The \${su_cmd} command set for privilege escalation in the \${name}.conf configuration file is not found\n")" && quit_msg
			exit 2
		fi
	fi
}

# Definition of the diff program to use (if it is set in the arch-update.conf configuration file)
check_diff_prog () {
	[ -n "${DIFFPROG}" ] && diff_prog="${DIFFPROG}"

	if [ -n "${diff_prog}" ]; then
		if ! command -v "${diff_prog%% *}" > /dev/null; then
			error_msg "$(eval_gettext "The \${diff_prog} editor set for visualizing / editing differences of pacnew files in the \${name}.conf configuration file is not found\n")" && quit_msg
			exit 15
		else
			if [ "${su_cmd}" == "sudo" ] || [ "${su_cmd}" == "sudo-rs" ]; then
				diff_prog_opt=("DIFFPROG=${diff_prog}")
			elif [ "${su_cmd}" == "doas" ]; then
				diff_prog_opt=("env" "DIFFPROG=${diff_prog}")
			elif [ "${su_cmd}" == "run0" ]; then
				diff_prog_opt+=("--setenv=DIFFPROG=${diff_prog}")
			fi
		fi
	fi
}

# Definition of the icon_up-to-date function: Change tray icon to "up to date"
icon_up-to-date() {
	# shellcheck disable=SC2154
	echo "linxira-update-${tray_icon_style}" > "${statedir}/tray_icon"
}

# Definition of the icon_updates-available function: Change tray icon to "updates available"
icon_updates-available() {
	# shellcheck disable=SC2154
	echo "linxira-update_updates-available-${tray_icon_style}${colorblind_mode}" > "${statedir}/tray_icon"
}

icon_check-error() {
	echo "dialog-warning" > "${statedir}/tray_icon"
}

# Linxira packages must come from a configured pacman repository, never the AUR.
# Use exact package names derived from a deliberately narrow ownership boundary.
detect_linxira_foreign_packages() {
	local package foreign_packages
	linxira_protected_packages=()
	aur_ignore_args=()
	if ! foreign_packages=$(pacman -Qmq 2> /dev/null); then
		linxira_source_detection_failed="true"
		unset aur_helper
		return 1
	fi
	while IFS= read -r package; do
		case "${package}" in
			linxira|linxira-*|calamares|shelly)
				if [[ "${package}" =~ ^[a-zA-Z0-9@._+:~-]+$ ]]; then
					linxira_protected_packages+=("${package}")
				fi
			;;
		esac
	done <<< "${foreign_packages}"

	if [ "${#linxira_protected_packages[@]}" -gt 0 ]; then
		local protected_csv
		printf -v protected_csv '%s,' "${linxira_protected_packages[@]}"
		aur_ignore_args=(--ignore "${protected_csv%,}")
	fi
	return 0
}

report_missing_linxira_source() {
	[ "${#linxira_protected_packages[@]}" -eq 0 ] && return 0
	warning_msg "$(eval_gettext "No configured pacman repository provides these installed Linxira packages: ")${linxira_protected_packages[*]}"
	warning_msg "$(eval_gettext "Their updates cannot be checked. Configure Linxira's signed package repository before treating this system as up to date.\n")"
	return 1
}

status_writer="${libdir}/write_status.py"

# Definition of commands to always run on exit (e.g. cleanup of files / dirs which have no purpose being kept)
cleanup() {
	# shellcheck disable=SC2154
	[ -d "${checkupdates_db_tmpdir}" ] && rm -rf "${checkupdates_db_tmpdir}"
	[ -n "${check_result_tmpdir:-}" ] && rm -rf "${check_result_tmpdir}"
	[ -n "${list_result_tmpdir:-}" ] && rm -rf "${list_result_tmpdir}"
	[ -n "${kernel_reboot}" ] && tput cnorm
}

trap cleanup EXIT
