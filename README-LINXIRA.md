# Linxira Update

Linxira Update is the system update notifier and maintenance assistant for
Linxira OS. It provides an interactive terminal workflow, a Qt system tray
applet, and a systemd user timer.

The default update scope is the installed pacman repositories. AUR and Flatpak
support are opt-in through `~/.config/linxira-update/linxira-update.conf`.
Installed foreign packages named `linxira` or prefixed with `linxira-` are
never sent to an AUR helper. If no configured pacman repository provides them,
the check is reported as incomplete instead of claiming the system is up to
date.

Arch Linux news remains available before upgrades because Linxira uses an Arch
base and those advisories can still require operator action.

Full unattended updates are opt-in via the `EnableAutoApply` option (off by
default). When enabled, updates are applied automatically only by the
unattended update service (`linxira-update.service`, which runs `--check` on
the user timer) and only when every safety gate passes: btrfs root
filesystem, Timeshift configured (`linxira-config timeshift enable`),
`grub-btrfs-overlayfs` in mkinitcpio HOOKS and `grub-btrfsd` enabled. A
dedicated pre-upgrade Timeshift snapshot is created and verified first; if
snapshotting fails the upgrade is refused. Tray and interactive terminal
checks always require manual confirmation regardless of this option. The
status file records the `auto_apply` outcome and the `pre_snapshot_id`
rollback point; every pacman transaction is also snapshotted by
`linxira-timeshift-autosnap.hook`, and snapshots boot from the GRUB menu
for rollback.

Commands:

```text
linxira-update
linxira-update --check
linxira-update --list
linxira-update --tray
linxira-update --gen-config
```

The update checker atomically publishes read-only status for other Linxira
applications at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/linxira-update/status.json
```

The `check_status` field is `ok`, `error`, or `incomplete`; consumers must not
interpret a zero update count as up to date unless this field is `ok`.

This project is derived from Cachy-Update and Arch-Update and remains licensed
under GPL-3.0-or-later. Upstream history and attribution are preserved in the
repository.

Linxira's signed package repository and signing key must be provisioned by the
OS distribution. This updater intentionally does not guess a repository URL or
enable a package source.

## 开发者批注（人类批注） / Maintainer Annotation (human-authored)

> 以下为维护者人工批注，非自动生成，也不是面向用户的对外承诺。

**推送通道现状**

> 推送需要稳定的服务器，目前测试r s s推送是有问题的无法保证安全更新和安全补丁包推送到位。

**补丁范围界定**

> 我们官方选过的那些可以在安装引导里面安装的那些软件和运行时开发工具，我们只负责打那边的补丁包以及一些更重要的底层补丁包。

**落地状态**

相关代码此前已在主力开发机上编写并测试过；该机的机械硬盘毁于 930 昆明盘龙地震（2026-09-30），主力开发机上的绝大多数前沿数据与个人科研数据因此损失。当前这棵工作树（本仓库）尚无下发通道，因此线上暂未提供该能力。
