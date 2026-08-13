#!/bin/bash

# check.sh: Check for available updates
# https://github.com/Antiz96/arch-update
# SPDX-License-Identifier: GPL-3.0-or-later

# Keep the last successful state intact until every enabled source has completed.
# shellcheck disable=SC2154
touch "${statedir}"/last_updates_check_{packages,aur,flatpak} "${statedir}/last_updates_check"
checkupdates_db_tmpdir=$(mktemp -d "${checkupdates_db_tmpdir_prefix}XXXXX")
check_result_tmpdir=$(mktemp -d "${statedir}/.check-result-XXXXX") || exit 16
trap 'rm -rf "${check_result_tmpdir}"; cleanup' EXIT
touch "${check_result_tmpdir}"/{packages,aur,flatpak}

check_errors=()
if [ -n "${flatpak_detection_failed}" ]; then
	check_errors+=("$(eval_gettext "Flatpak package detection failed or timed out")")
fi
if ! detect_linxira_foreign_packages; then
	check_errors+=("$(eval_gettext "Unable to determine Linxira package ownership")")
elif ! report_missing_linxira_source; then
	check_incomplete="true"
fi

timeout --kill-after=5s "${update_check_timeout}" env CHECKUPDATES_DB="${checkupdates_db_tmpdir}" \
	checkupdates --nocolor > "${check_result_tmpdir}/packages"
packages_exit_code=$?
if [ "${packages_exit_code}" -ne 0 ] && [ "${packages_exit_code}" -ne 2 ]; then
	if [ "${packages_exit_code}" -eq 124 ]; then
		check_errors+=("$(eval_gettext "Package update check timed out")")
	else
		check_errors+=("$(eval_gettext "Package update check failed")")
	fi
fi

if [ -n "${aur_helper}" ]; then
	timeout --kill-after=5s "${update_check_timeout}" "${aur_helper}" --color never \
		"${aur_ignore_args[@]}" -Qua < /dev/null 2> /dev/null > "${check_result_tmpdir}/aur.raw"
	aur_exit_code=$?
	if [ "${aur_exit_code}" -eq 0 ]; then
		sed 's/^ *//;s/ \+/ /g' "${check_result_tmpdir}/aur.raw" | grep -vw "\[ignored\]$" > "${check_result_tmpdir}/aur" || true
	elif [ "${aur_exit_code}" -eq 124 ]; then
		check_errors+=("$(eval_gettext "AUR update check timed out")")
	else
		check_errors+=("$(eval_gettext "AUR update check failed")")
	fi
fi

if [ -n "${flatpak_support}" ]; then
	timeout --foreground --kill-after=5s "${update_check_timeout}" flatpak update --appstream > /dev/null
	flatpak_exit_code=$?
	if [ "${flatpak_exit_code}" -eq 0 ]; then
		flatpak_mask=$(timeout --foreground --kill-after=5s "${update_check_timeout}" flatpak mask)
		flatpak_mask_exit_code=$?
		flatpak_updates=$(timeout --foreground --kill-after=5s "${update_check_timeout}" flatpak remote-ls --updates --cached --columns=application,name,version)
		flatpak_updates_exit_code=$?
		if [ "${flatpak_mask_exit_code}" -eq 0 ] && [ "${flatpak_updates_exit_code}" -eq 0 ]; then
			while IFS=$'\t' read -r app_id app_name app_version; do
				[ -z "${app_id}" ] && continue
				masked=""
				while IFS= read -r pattern; do
					pattern=${pattern//[[:space:]]/}
					# shellcheck disable=SC2053
					if [ -n "${pattern}" ] && [[ "${app_id}" == ${pattern} ]]; then
						masked="true"
						break
					fi
				done <<< "${flatpak_mask}"
				[ -n "${masked}" ] && continue
				if [ -n "${no_version}" ]; then
					printf '%s\n' "${app_name:-${app_id}}"
				else
					printf '%s %s\n' "${app_name:-${app_id}}" "${app_version}"
				fi
			done <<< "${flatpak_updates}" > "${check_result_tmpdir}/flatpak"
		else
			check_errors+=("$(eval_gettext "Flatpak update check failed")")
		fi
	elif [ "${flatpak_exit_code}" -eq 124 ]; then
		check_errors+=("$(eval_gettext "Flatpak update check timed out")")
	else
		check_errors+=("$(eval_gettext "Flatpak update check failed")")
	fi
fi

if [ "${#check_errors[@]}" -gt 0 ]; then
	check_message=$(IFS='; '; echo "${check_errors[*]}")
	error_msg "${check_message}"
	# Linxira: 常见根因提示(加速器/hosts 劫持 github.io 会导致 [linxira] 仓库 db 同步失败)
	error_msg "$(eval_gettext "If the [linxira] repository cannot be reached: run 'sudo pacman -Syy' once and verify connectivity to linxira-os.github.io (VPN / hosts redirection may block it).")"
	icon_check-error
	previous_count=$(sed '/^[[:space:]]*$/d' "${statedir}/last_updates_check" | wc -l)
	"${status_writer}" --state-dir "${statedir}" --available-count "${previous_count}" \
		--check-status error --message "${check_message}" || exit 18
	if [ -t 0 ] && [ -t 1 ]; then
		read -rp "$(eval_gettext "Press Enter to close...")" || true
	fi
	exit 18
fi

if [ -n "${no_version}" ]; then
	awk '{print $1}' "${check_result_tmpdir}/packages" > "${check_result_tmpdir}/packages.names"
	mv "${check_result_tmpdir}/packages.names" "${check_result_tmpdir}/packages"
	awk '{print $1}' "${check_result_tmpdir}/aur" > "${check_result_tmpdir}/aur.names"
	mv "${check_result_tmpdir}/aur.names" "${check_result_tmpdir}/aur"
fi

sed -i '/^[[:space:]]*$/d' "${check_result_tmpdir}"/{packages,aur,flatpak}
sed -ri 's/\x1B\[[0-9;]*m//g' "${check_result_tmpdir}"/{packages,aur,flatpak}
cat "${check_result_tmpdir}"/{packages,aur,flatpak} > "${check_result_tmpdir}/all"
update_available=$(cat "${check_result_tmpdir}/all")

for category in packages aur flatpak; do
	if ! mv -f "${check_result_tmpdir}/${category}" "${statedir}/last_updates_check_${category}"; then
		error_msg "$(eval_gettext "Unable to publish update check state")"
		exit 18
	fi
done

if [ -n "${update_available}" ]; then
	icon_updates-available
	if [ -n "${notification_support}" ] && ! diff "${check_result_tmpdir}/all" "${statedir}/last_updates_check" &> /dev/null; then
		update_number=$(wc -l < "${check_result_tmpdir}/all")
		last_notif_id=$(sed -n '1p' "${tmpdir}/notif_param" 2> /dev/null)
		systemd-run --user --unit="${name}"-notification-"$(date +%Y%m%d-%H%M%S)" --quiet \
			--setenv=DISPLAY="${DISPLAY}" --setenv=DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" \
			--setenv=TEXTDOMAIN="${text_domain}" --setenv=TEXTDOMAINDIR="${TEXTDOMAINDIR}" \
			--setenv=LANG="${LANG}" --setenv=LANGUAGE="${LANGUAGE}" --setenv=LC_ALL="${LC_ALL}" \
			--setenv=LC_MESSAGES="${LC_MESSAGES}" --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
			--setenv=XDG_DATA_HOME="${XDG_DATA_HOME}" --setenv=XDG_DATA_DIRS="${XDG_DATA_DIRS}" \
			--setenv=HOME="${HOME}" --setenv=update_number="${update_number}" \
			--setenv=last_notif_id="${last_notif_id}" --setenv=_name="${_name}" --setenv=name="${name}" \
			--setenv=tray_icon_style="${tray_icon_style}" --setenv=colorblind_mode="${colorblind_mode}" \
			--setenv=tmpdir="${tmpdir}" --setenv=desktop_file="${desktop_file}" "${libdir}/notification.sh"
	fi
elif [ -z "${check_incomplete}" ]; then
	icon_up-to-date
fi

if ! mv -f "${check_result_tmpdir}/all" "${statedir}/last_updates_check"; then
	error_msg "$(eval_gettext "Unable to publish update check state")"
	exit 18
fi
update_number=$(sed '/^[[:space:]]*$/d' "${statedir}/last_updates_check" | wc -l)
if [ -n "${check_incomplete}" ]; then
	[ -z "${update_available}" ] && icon_check-error
	check_message="$(eval_gettext "Installed Linxira packages lack a configured update source")"
	error_msg "${check_message}"
	error_msg "$(eval_gettext "The [linxira] repository must be reachable: run 'sudo pacman -Syy' once and verify connectivity to linxira-os.github.io (VPN / hosts redirection may block it).")"
	"${status_writer}" --state-dir "${statedir}" --available-count "${update_number}" \
		--check-status incomplete --message "${check_message}" || exit 18
	if [ -t 0 ] && [ -t 1 ]; then
		read -rp "$(eval_gettext "Press Enter to close...")" || true
	fi
	exit 19
fi
"${status_writer}" --state-dir "${statedir}" --available-count "${update_number}" || exit 18
