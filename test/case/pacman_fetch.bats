#!/usr/bin/env bats

@test "zeta Pages URLs rewrite to the release asset" {
	run src/linxira-pacman-fetch.sh --print-urls \
		"https://linxira-os.github.io/packages/zeta/x86_64/linxira-zeta-1.4.5-1-x86_64.pkg.tar.zst"
	[ "${status}" -eq 0 ]
	[ "${lines[0]}" = "https://github.com/Linxira-OS/packages/releases/download/zeta-repo/linxira-zeta-1.4.5-1-x86_64.pkg.tar.zst" ]
}

@test "GitHub URLs get proxy candidates" {
	run src/linxira-pacman-fetch.sh --print-urls \
		"https://github.com/Linxira-OS/packages/releases/download/zeta-repo/linxira-zeta.db"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"https://gh-proxy.com/https://github.com/Linxira-OS/packages/releases/download/zeta-repo/linxira-zeta.db"* ]]
	[[ "${output}" == *"https://ghfast.top/https://github.com/Linxira-OS/packages/releases/download/zeta-repo/linxira-zeta.db"* ]]
}

@test "non-GitHub URLs pass through unchanged" {
	run src/linxira-pacman-fetch.sh --print-urls \
		"https://geo.mirror.pkgbuild.com/core/os/x86_64/bash-5.3-1-x86_64.pkg.tar.zst"
	[ "${status}" -eq 0 ]
	[ "${output}" = "https://geo.mirror.pkgbuild.com/core/os/x86_64/bash-5.3-1-x86_64.pkg.tar.zst" ]
}
