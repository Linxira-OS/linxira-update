#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# pacman XferCommand adapter for GitHub-backed repositories.
#
# Large GitHub release assets (the zeta suite) are the downloads that fail on
# mainland links: a direct connection can stall below libcurl's low-speed
# threshold, and GitHub Pages is slower than the release CDN.  On every call
# this adapter probes the configured accelerators with a small range request,
# rewrites GitHub URLs (including the zeta Pages mirror) through the fastest
# one, and resumes partial files on the next attempt.  Probing is intentionally
# uncached: users behind a VPN or a local hosts accelerator can have a
# different winner on every run.
#
# The script never edits pacman.conf itself; linxira-update's package install
# script adds the XferCommand line once.  Without that line it is inert.

set -uo pipefail

CONFIG_FILE="${LINXIRA_FETCH_CONFIG:-/etc/linxira/update-mirrors.conf}"
PROBE_CACHE="${LINXIRA_FETCH_CACHE:-/var/cache/linxira-update/mirror-probe}"
PROBE_TTL="${LINXIRA_FETCH_TTL:-3600}"
PROBE_BYTES="${LINXIRA_FETCH_PROBE_BYTES:-131072}"
PROBE_TIMEOUT="${LINXIRA_FETCH_PROBE_TIMEOUT:-5}"

ZETA_PAGES_PREFIX="https://linxira-os.github.io/packages/zeta/"
ZETA_RELEASE_PREFIX="https://github.com/Linxira-OS/packages/releases/download/zeta-repo/"
GITHUB_PREFIX="https://github.com/"

# A local VPN/hosts accelerator makes "direct" the fastest candidate, so it is
# always probed; public proxies are only fallbacks.
DEFAULT_MIRRORS=(
	"direct"
	"https://gh-proxy.com/"
	"https://ghfast.top/"
	"https://cdn.akaere.online/"
)

configured_mirrors() {
	local line
	local -a mirrors=()
	if [ -r "${CONFIG_FILE}" ]; then
		while IFS= read -r line || [ -n "${line}" ]; do
			line="${line%%#*}"
			line="${line#"${line%%[![:space:]]*}"}"
			line="${line%"${line##*[![:space:]]}"}"
			[ -n "${line}" ] || continue
			mirrors+=("${line}")
		done < "${CONFIG_FILE}"
	fi
	if [ "${#mirrors[@]}" -eq 0 ]; then
		mirrors=("${DEFAULT_MIRRORS[@]}")
	fi
	local have_direct=0
	for line in "${mirrors[@]}"; do
		[ "${line}" = "direct" ] && have_direct=1
	done
	[ "${have_direct}" -eq 1 ] || mirrors+=("direct")
	printf '%s\n' "${mirrors[@]}"
}

apply_prefix() {
	local prefix="$1"
	local url="$2"
	if [ "${prefix}" = "direct" ] || [ -z "${prefix}" ]; then
		printf '%s\n' "${url}"
	else
		printf '%s%s\n' "${prefix}" "${url}"
	fi
}

rewrite_url() {
	local url="$1"
	case "${url}" in
		"${ZETA_PAGES_PREFIX}"*)
			local file="${url#"${ZETA_PAGES_PREFIX}"}"
			file="${file##*/}"
			printf '%s%s\n' "${ZETA_RELEASE_PREFIX}" "${file}"
			;;
		*)
			printf '%s\n' "${url}"
			;;
	esac
}

is_github_url() {
	case "$1" in
		"${GITHUB_PREFIX}"*) return 0 ;;
		*) return 1 ;;
	esac
}

probe_prefix() {
	local prefix="$1"
	local url="$2"
	local result code speed
	result="$(curl -fsSL --range "0-$((PROBE_BYTES - 1))" --max-time "${PROBE_TIMEOUT}" \
		-o /dev/null -w '%{http_code}|%{speed_download}' "$(apply_prefix "${prefix}" "${url}")" 2>/dev/null)" || return 1
	code="${result%%|*}"
	speed="${result#*|}"
	case "${code}" in
		200 | 206) ;;
		*) return 1 ;;
	esac
	case "${speed}" in
		'' | 0 | 0.000*) return 1 ;;
	esac
	printf '%s\n' "${speed}"
}

read_cached_prefix() {
	[ -r "${PROBE_CACHE}" ] || return 1
	local stamp prefix speed now
	IFS='|' read -r stamp prefix speed < "${PROBE_CACHE}" || return 1
	now="$(date +%s)"
	[ $((now - stamp)) -lt "${PROBE_TTL}" ] || return 1
	configured_mirrors | grep -qxF -- "${prefix}" || return 1
	printf '%s\n' "${prefix}"
}

write_cached_prefix() {
	mkdir -p "$(dirname "${PROBE_CACHE}")" 2>/dev/null || return 0
	printf '%s|%s|%s\n' "$(date +%s)" "$1" "$2" > "${PROBE_CACHE}.tmp" 2>/dev/null &&
		mv "${PROBE_CACHE}.tmp" "${PROBE_CACHE}" 2>/dev/null
}

choose_prefix() {
	local url="$1"
	local cached
	if cached="$(read_cached_prefix)"; then
		printf '%s\n' "${cached}"
		return 0
	fi
	local prefix speed best_prefix="direct" best_speed=0
	while IFS= read -r prefix; do
		[ -n "${prefix}" ] || continue
		if speed="$(probe_prefix "${prefix}" "${url}")"; then
			if [ "${speed%.*}" -gt "${best_speed%.*}" ] 2>/dev/null; then
				best_speed="${speed}"
				best_prefix="${prefix}"
			fi
		fi
	done < <(configured_mirrors)
	write_cached_prefix "${best_prefix}" "${best_speed}"
	printf '%s\n' "${best_prefix}"
}

candidates_for() {
	local url="$1"
	local chosen prefix
	chosen="$(choose_prefix "${url}")"
	apply_prefix "${chosen}" "${url}"
	while IFS= read -r prefix; do
		[ "${prefix}" = "${chosen}" ] && continue
		apply_prefix "${prefix}" "${url}"
	done < <(configured_mirrors)
}

download() {
	local url="$1"
	local output="$2"
	local -a curl_args=(
		-fL
		--retry 3
		--retry-delay 2
		--connect-timeout 20
		--speed-limit 1024
		--speed-time 60
	)
	# pacman reuses the same output path; continue from whatever was written
	# when the previous source stalled.
	if [ -s "${output}" ]; then
		curl_args+=(-C -)
	fi
	curl "${curl_args[@]}" -o "${output}" "${url}"
}

print_urls() {
	local url
	url="$(rewrite_url "$1")"
	if ! is_github_url "${url}"; then
		printf '%s\n' "${url}"
		return 0
	fi
	local prefix
	while IFS= read -r prefix; do
		apply_prefix "${prefix}" "${url}"
	done < <(configured_mirrors)
}

if [ "${1:-}" = "--print-urls" ]; then
	[ "$#" -ge 2 ] || {
		echo "usage: $0 --print-urls URL" >&2
		exit 2
	}
	print_urls "$2"
	exit 0
fi

[ "$#" -eq 2 ] || {
	echo "usage: $0 URL OUTPUT" >&2
	exit 2
}

url="$1"
output="$2"

case "${url}" in
	file://*)
		cp -- "${url#file://}" "${output}"
		exit $?
		;;
esac

rewritten="$(rewrite_url "${url}")"
if is_github_url "${rewritten}"; then
	while IFS= read -r candidate; do
		download "${candidate}" "${output}" && exit 0
	done < <(candidates_for "${rewritten}")
	echo "linxira-pacman-fetch: every mirror failed for ${rewritten}" >&2
	rm -f "${PROBE_CACHE}" 2>/dev/null
	exit 1
fi

download "${url}" "${output}"
