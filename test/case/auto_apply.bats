export LINXIRA_UPDATE_LIBDIR="${PWD}/src/lib"

# EnableAutoApply 门控/快照/应用契约测试。全部外部命令走 FAKE_BIN 注入：
# findmnt/systemctl/timeshift/pacman 为桩，status_writer 把参数逐行落到 status_calls。

setup() {
	FAKE_BIN="${BATS_TEST_TMPDIR}/bin"
	STATE="${BATS_TEST_TMPDIR}/state"
	mkdir -p "${FAKE_BIN}" "${STATE}"
	export PATH="${FAKE_BIN}:${PATH}"
	export STATE
	export timeshift_conf="${BATS_TEST_TMPDIR}/timeshift.json"
	export mkinitcpio_conf="${BATS_TEST_TMPDIR}/mkinitcpio.conf"
	name="linxira-update"
	_name="Linxira Update"
	statedir="${STATE}"
	status_writer="${FAKE_BIN}/status_writer"
	update_number="3"
	pacman_color_opt="auto"
	notification_support=""
	eval_gettext() { printf '%s' "$1"; }
	icon_up-to-date() { :; }
	icon_check-error() { :; }
	printf 'HOOKS=(base udev autodetect microcode)\n' > "${mkinitcpio_conf}"
	cat > "${FAKE_BIN}/status_writer" <<'EOS'
#!/bin/bash
printf '%s\n' "$@" >> "${STATE}/status_calls"
EOS
	cat > "${FAKE_BIN}/findmnt" <<'EOF'
#!/bin/bash
printf '%s\n' "${FAKE_ROOT_FS:-btrfs}"
EOF
	cat > "${FAKE_BIN}/systemctl" <<'EOF'
#!/bin/bash
exit 0
EOF
	cat > "${FAKE_BIN}/timeshift" <<'EOF'
#!/bin/bash
if [ "${1}" = "--create" ]; then
	if [ -n "${FAKE_SNAPSHOT_FAIL}" ]; then exit 1; fi
	while [ "${#}" -gt 0 ]; do
		if [ "${1}" = "--comments" ]; then
			printf '%s\n' "${2}" >> "${FAKE_BIN}/snapshots"
		fi
		shift
	done
	exit 0
fi
if [ "${1}" = "--list" ]; then
	cat "${FAKE_BIN}/snapshots" 2> /dev/null
	exit 0
fi
exit 0
EOF
	cat > "${FAKE_BIN}/pacman" <<'EOF'
#!/bin/bash
touch "${STATE}/pacman_ran"
if [ -n "${FAKE_UPGRADE_FAIL}" ]; then exit 1; fi
exit 0
EOF
	chmod +x "${FAKE_BIN}"/status_writer "${FAKE_BIN}"/findmnt "${FAKE_BIN}"/systemctl "${FAKE_BIN}"/timeshift "${FAKE_BIN}"/pacman
	unset FAKE_SNAPSHOT_FAIL FAKE_UPGRADE_FAIL FAKE_ROOT_FS
	su_cmd="env"
}

config_enabled() {
	enable_auto_apply="true"
	# shellcheck source=src/lib/auto_apply.sh
	source src/lib/auto_apply.sh
}

gate_ready() {
	printf 'timeshift configured\n' > "${timeshift_conf}"
	sed -i 's/microcode)/microcode grub-btrfs-overlayfs)/' "${mkinitcpio_conf}"
}

@test "gate refusal records reason and never upgrades" {
	config_enabled
	run_auto_apply
	grep -Fq -- "--auto-apply" "${STATE}/status_calls"
	grep -Fxq "false" "${STATE}/status_calls"
	grep -Fq "timeshift is not configured" "${STATE}/status_calls"
	[ ! -f "${STATE}/pacman_ran" ]
}

@test "non-btrfs root refuses auto-apply" {
	config_enabled
	gate_ready
	export FAKE_ROOT_FS=ext4
	run_auto_apply
	unset FAKE_ROOT_FS
	grep -Fq "not btrfs" "${STATE}/status_calls"
	[ ! -f "${STATE}/pacman_ran" ]
}

@test "snapshot failure refuses the upgrade" {
	config_enabled
	gate_ready
	FAKE_SNAPSHOT_FAIL=1 run_auto_apply
	grep -Fq "pre-upgrade snapshot failed" "${STATE}/status_calls"
	[ ! -f "${STATE}/pacman_ran" ]
}

@test "compliant system applies updates and publishes snapshot id" {
	config_enabled
	gate_ready
	run_auto_apply
	[ -f "${STATE}/pacman_ran" ]
	grep -Fxq "true" "${STATE}/status_calls"
	grep -Fxq -- "--pre-snapshot-id" "${STATE}/status_calls"
	grep -Fxq "0" "${STATE}/status_calls"
}

@test "failed upgrade reports the rollback snapshot as error" {
	config_enabled
	gate_ready
	FAKE_UPGRADE_FAIL=1 run_auto_apply
	[ -f "${STATE}/pacman_ran" ]
	grep -Fxq "error" "${STATE}/status_calls"
	grep -Fq "rollback point" "${STATE}/status_calls"
	grep -Fxq "false" "${STATE}/status_calls"
}

@test "zero updates never triggers apply" {
	config_enabled
	gate_ready
	update_number="0"
	run_auto_apply
	[ ! -f "${STATE}/status_calls" ]
	[ ! -f "${STATE}/pacman_ran" ]
}
