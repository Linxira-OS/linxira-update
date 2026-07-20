export LINXIRA_UPDATE_LIBDIR="${PWD}/src/lib"

@test "version" {
	src/arch-update.sh --version | grep -F "Linxira Update 0.1.0"
}

@test "help" {
	src/arch-update.sh --help
}
