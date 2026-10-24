#!/bin/bash

# invalid_option.sh: Display an error message when an invalid option is passed, hint users to check the help and exit
# Based on Arch-Update: Copyright (C) 2021-2026 Antiz96 (https://github.com/Antiz96/arch-update)
# Modified by Linxira OS contributors (2026-10-24); see UPSTREAM.md for the change list.
# SPDX-License-Identifier: GPL-3.0-or-later

echo -e >&2 "$(eval_gettext "\${name}: invalid option -- '\${option}'\nTry '\${name} --help' for more information")"
exit 1
