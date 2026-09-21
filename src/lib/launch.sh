#!/bin/bash
# launch.sh: Open the interactive update workflow inside an available terminal.
# SPDX-License-Identifier: GPL-3.0-or-later

# 2026-09-21: COSMIC 等桌面没有 gio 终端接力, .desktop 的 Terminal=true 会
# 静默失效(点击无反应)。按本机实际存在的终端依次回退, 保证任何桌面都能
# 打开交互式更新窗口。

launch_update_terminal() {
	local terminal command
	for terminal in /usr/bin/cosmic-term /usr/bin/konsole /usr/bin/xterm; do
		[ -x "${terminal}" ] || continue
		case "${terminal}" in
			*cosmic-term)
				command=("${terminal}" -e linxira-update)
			;;
			*konsole)
				command=("${terminal}" --hold -e linxira-update)
			;;
			*)
				command=("${terminal}" -hold -e linxira-update)
			;;
		esac
		printf '%s\n' "Launching update workflow in ${terminal}" >&2
		setsid "${command[@]}" > /dev/null 2>&1 &
		return 0
	done
	error_msg "$(eval_gettext "No terminal emulator found (cosmic-term, konsole or xterm)")"
	return 1
}

launch_update_terminal
