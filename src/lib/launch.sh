#!/bin/bash
# launch.sh: Open the interactive update workflow inside an available terminal.
# SPDX-License-Identifier: GPL-3.0-or-later

# 2026-11-01: cosmic-term 1.10+ supports -e.  Dispatch directly instead of
# relying on the Terminal=true/gtk-launch relay, which is unreliable on COSMIC.
# COSMIC prefers cosmic-term; KDE/other sessions keep konsole first.
launch_update_terminal() {
	local terminal
	local -a terminals flags
	local desktop_names="${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-}"
	desktop_names="${desktop_names^^}"

	if [[ "${desktop_names}" == *COSMIC* ]]; then
		terminals=(/usr/bin/cosmic-term /usr/bin/konsole /usr/bin/alacritty /usr/bin/xterm)
	else
		terminals=(/usr/bin/konsole /usr/bin/cosmic-term /usr/bin/alacritty /usr/bin/xterm)
	fi

	for terminal in "${terminals[@]}"; do
		[ -x "${terminal}" ] || continue
		case "${terminal}" in
			*/cosmic-term) flags=(-e) ;;
			*/alacritty) flags=(--hold -e) ;;
			*/xterm) flags=(-hold -e) ;;
			*) flags=(--hold -e) ;;
		esac
		setsid "${terminal}" "${flags[@]}" linxira-update > /dev/null 2>&1 &
		return 0
	done
	error_msg "$(eval_gettext "No terminal emulator found (konsole, alacritty, xterm or cosmic-term)")"
	return 1
}

launch_update_terminal
