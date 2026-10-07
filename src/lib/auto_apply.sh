#!/bin/bash

# auto_apply.sh: 全自动更新（EnableAutoApply，默认关）——硬门控 + 升级前快照 + 非交互应用
# 契约（2026-10-08 定稿，HANDOVER「2026-10-08」节）：
#   门控 = btrfs 根文件系统 + timeshift 已配置 + mkinitcpio HOOKS 含
#          grub-btrfs-overlayfs + grub-btrfsd 已启用 + 存在可用提权命令
#   门控/快照任一失败 → 拒绝应用，status.json 记 auto_apply=false + 原因（不阻塞检查本身）
#   全部通过 → timeshift --create（显式，且校验快照入列）→ su_cmd pacman -Syu --noconfirm
#              → status.json 记 pre_snapshot_id + auto_apply=true
# 不做 AUR/Flatpak，不做白名单部分升级（Arch 部分升级纪律）。回滚底座 =
# linxira-timeshift-autosnap.hook + grub-btrfsd 自动 GRUB 条目 + grub-btrfs-overlayfs 只读引导。

# 可注入路径（测试/非常规布局）；findmnt/systemctl/timeshift/pacman 走 PATH 注入。
# shellcheck disable=SC2034
timeshift_conf="${timeshift_conf:-/etc/timeshift/timeshift.json}"
# shellcheck disable=SC2034
mkinitcpio_conf="${mkinitcpio_conf:-/etc/mkinitcpio.conf}"

auto_apply_check_gates() {
	auto_apply_reason=""
	if ! command -v timeshift > /dev/null 2>&1; then
		# shellcheck disable=SC2034
		auto_apply_reason="timeshift is not installed"
		return 1
	fi
	if [ ! -f "${timeshift_conf}" ]; then
		# shellcheck disable=SC2034
		auto_apply_reason="timeshift is not configured (run: linxira-config timeshift enable)"
		return 1
	fi
	auto_apply_root_fs=$(findmnt -n -o FSTYPE / 2> /dev/null)
	if [ "${auto_apply_root_fs}" != "btrfs" ]; then
		# shellcheck disable=SC2034
		auto_apply_reason="root filesystem is '${auto_apply_root_fs:-unknown}', not btrfs"
		return 1
	fi
	if ! grep -qE '^HOOKS=\(.*grub-btrfs-overlayfs' "${mkinitcpio_conf}" 2> /dev/null; then
		# shellcheck disable=SC2034
		auto_apply_reason="grub-btrfs-overlayfs is missing from mkinitcpio HOOKS"
		return 1
	fi
	if ! systemctl is-enabled --quiet grub-btrfsd.service 2> /dev/null; then
		# shellcheck disable=SC2034
		auto_apply_reason="grub-btrfsd service is not enabled"
		return 1
	fi
	if [ -z "${su_cmd}" ]; then
		local candidate
		for candidate in sudo sudo-rs doas run0; do
			if command -v "${candidate}" > /dev/null 2>&1; then
				su_cmd="${candidate}"
				break
			fi
		done
	fi
	if [ -z "${su_cmd}" ] || ! command -v "${su_cmd}" > /dev/null 2>&1; then
		# shellcheck disable=SC2034
		auto_apply_reason="no usable privilege elevation command (sudo/sudo-rs/doas/run0)"
		return 1
	fi
	return 0
}

auto_apply_snapshot() {
	# $1 = 唯一 token；成功置 auto_apply_snapshot_id 并回 0。
	# 只看 create 退出码会漏"半失败"，故再校验快照按唯一注释入列。
	auto_apply_comment="linxira-update pre-upgrade $1"
	if ! "${su_cmd}" timeshift --create --comments "${auto_apply_comment}" --tags O > "${auto_apply_tmpdir}/snapshot.log" 2>&1; then
		return 1
	fi
	if ! "${su_cmd}" timeshift --list 2> /dev/null | grep -Fq "${auto_apply_comment}"; then
		return 1
	fi
	auto_apply_snapshot_id="$1"
	return 0
}

auto_apply_publish() {
	# $1=auto_apply(true/false) $2=available_count $3=check_status $4=message $5=pre_snapshot_id(可空)
	local flag="$1" count="$2" status="$3" message="$4" snapshot="$5"
	local args=(--state-dir "${statedir}" --available-count "${count}" --auto-apply "${flag}")
	[ "${status}" != "ok" ] && args+=(--check-status "${status}")
	[ -n "${message}" ] && args+=(--message "${message}")
	[ -n "${snapshot}" ] && args+=(--pre-snapshot-id "${snapshot}")
	"${status_writer}" "${args[@]}" || exit 18
}

run_auto_apply() {
	# 触发面硬门控: 仅无人值守服务单元（arch-update.service 注入 LINXIRA_UPDATE_UNATTENDED=1）
	# 允许自动应用；托盘/终端手动 --check 永不自动应用。TTY 检查为纵深防御。
	if [ -z "${LINXIRA_UPDATE_UNATTENDED:-}" ] || [ -t 0 ] || [ -t 1 ]; then
		return 0
	fi
	[ "${update_number}" -eq 0 ] && return 0
	# 与 --launch/full_upgrade 共用同一锁文件：拿不到锁说明有交互升级在跑，
	# 静默跳过本轮（下个检查周期重试），锁竞争不误报为升级失败。
	exec {fd_auto_apply}> "${TMPDIR:-/tmp}/${name}.lock"
	if ! flock -n "${fd_auto_apply}"; then
		return 0
	fi
	auto_apply_tmpdir=$(mktemp -d "${statedir}/.auto-apply-XXXXX") || return 0
	pacman_color_opt="${pacman_color_opt:-auto}"

	if ! auto_apply_check_gates; then
		auto_apply_publish false "${update_number}" ok "EnableAutoApply: ${auto_apply_reason}" ""
		rm -rf "${auto_apply_tmpdir}"
		return 0
	fi

	if ! auto_apply_snapshot "$(date -u +%Y%m%dT%H%M%SZ)"; then
		auto_apply_publish false "${update_number}" ok "EnableAutoApply: pre-upgrade snapshot failed; upgrade refused" ""
		rm -rf "${auto_apply_tmpdir}"
		return 0
	fi

	if "${su_cmd}" pacman --color "${pacman_color_opt}" -Syu --noconfirm > "${auto_apply_tmpdir}/upgrade.log" 2>&1; then
		true > "${statedir}/last_updates_check_packages"
		cat "${statedir}"/last_updates_check_{packages,aur,flatpak} 2> /dev/null > "${statedir}/last_updates_check" || true
		icon_up-to-date
		auto_apply_publish true 0 ok "$(eval_gettext "Updates applied automatically (pre-upgrade snapshot: \${auto_apply_snapshot_id})")" "${auto_apply_snapshot_id}"
		if [ -n "${notification_support}" ]; then
			notify-send --app-name="${_name}" --icon="linxira-update_updates-available-${tray_icon_style}${colorblind_mode}" \
				"$(eval_gettext "Updates applied automatically")" \
				"$(eval_gettext "Pre-upgrade snapshot: \${auto_apply_snapshot_id}")" 2> /dev/null || true
		fi
	else
		icon_check-error
		auto_apply_publish false "${update_number}" error \
			"$(eval_gettext "EnableAutoApply: system upgrade failed; rollback point: \${auto_apply_snapshot_id}")" "${auto_apply_snapshot_id}"
	fi
	rm -rf "${auto_apply_tmpdir}"
}
