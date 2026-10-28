#!/bin/bash
# launch.sh: Open the interactive update workflow inside an available terminal.
# SPDX-License-Identifier: GPL-3.0-or-later

# 2026-10-27: 只派发支持 exec 标志的终端; cosmic-term 走 Terminal=true 桌面条目。
# 不要给 cosmic-term 传 -e: 它只认 -w/--working-directory, 位置参数被当成
# 文件/工作目录, 进程启动即退, 窗口一闪就没了(COSMIC 下表现为"点了没反应")。

launch_update_terminal() {
	local terminal
	for terminal in /usr/bin/konsole /usr/bin/alacritty /usr/bin/xterm; do
		[ -x "${terminal}" ] || continue
		setsid "${terminal}" -e linxira-update > /dev/null 2>&1 &
		return 0
	done
	if [ -x /usr/bin/cosmic-term ] && command -v gtk-launch > /dev/null; then
		local entry="${XDG_DATA_HOME:-${HOME}/.local/share}/applications/linxira-update-$$.desktop"
		mkdir -p "${entry%/*}" || return 1
		printf '[Desktop Entry]\nType=Application\nName=Linxira Update\nExec=linxira-update\nTerminal=true\nNoDisplay=true\n' > "${entry}" || return 1
		setsid gtk-launch "linxira-update-$$" > /dev/null 2>&1 &
		( sleep 5; rm -f "${entry}" ) > /dev/null 2>&1 &
		return 0
	fi
	error_msg "$(eval_gettext "No terminal emulator found (konsole, alacritty, xterm or cosmic-term)")"
	return 1
}

launch_update_terminal
