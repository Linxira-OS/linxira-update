#!/bin/bash

# edit-config.sh: Edit the current "arch-update.conf" configuration file
# Based on Arch-Update: Copyright (C) 2021-2026 Antiz96 (https://github.com/Antiz96/arch-update)
# Modified by Linxira OS contributors (2026-10-24); see UPSTREAM.md for the change list.
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2154
if [ ! -f "${config_file}" ]; then
	error_msg "$(eval_gettext "No configuration file found\nYou can generate one with \"\${name} --gen-config\"")"
	exit 13
else
	if ! "${EDITOR:-nano}" "${config_file}" 2> /dev/null; then
		error_msg "$(eval_gettext "Unable to determine the editor to use\nThe \"EDITOR\" environment variable is not set and \"nano\" (fallback option) is not installed")"
		exit 13
	fi
fi
