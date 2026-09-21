export LINXIRA_UPDATE_LIBDIR="${PWD}/src/lib"

@test "version" {
	src/arch-update.sh --version | grep -F "Linxira Update 0.1.0"
}

@test "help" {
	src/arch-update.sh --help
}

@test "AUR and Flatpak are opt-in" {
	export HOME="${BATS_TEST_TMPDIR}/home"
	name="linxira-update"
	unset enable_aur enable_flatpak no_aur no_flatpak
	source src/lib/config.sh
	[ "${no_aur}" = "true" ]
	[ "${no_flatpak}" = "true" ]
}

@test "Linxira foreign packages become exact AUR ignores" {
	name="linxira-update"
	text_domain="Linxira-Update"
	libdir="${PWD}/src/lib"
	option="--test"
	no_flatpak="true"
	no_notification="true"
	export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
	pacman() {
		if [ "${1}" = "-Qmq" ]; then
			printf '%s\n' linxira linxira-update calamares shelly unrelated-package notlinxira-tool
		fi
	}
	source src/lib/common.sh
	detect_linxira_foreign_packages
	[ "${linxira_protected_packages[*]}" = "linxira linxira-update calamares shelly" ]
	[ "${aur_ignore_args[*]}" = "--ignore linxira,linxira-update,calamares,shelly" ]
}

@test "Empty foreign package set (repo-managed system) is not a detection failure" {
	name="linxira-update"
	text_domain="Linxira-Update"
	libdir="${PWD}/src/lib"
	option="--test"
	no_flatpak="true"
	no_notification="true"
	export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state2"
	pacman() {
		# 2026-09-21: pacman -Qmq 无匹配(空集)时返回 1
		if [ "${1}" = "-Qmq" ]; then
			return 1
		fi
	}
	source src/lib/common.sh
	detect_linxira_foreign_packages
	[ "${linxira_source_detection_failed:-}" != "true" ]
	[ -z "${linxira_protected_packages[*]}" ]
}
