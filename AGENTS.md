# linxira-update · Agent 开发规范

> **档位**:A · 系统源仓
> **本仓职责**:Linxira OS 的系统更新通知与维护助手,提供交互式终端流程、Qt 托盘小程序与 systemd 用户定时器。
> 通用约束见工作区总纲 `f:\Linxira-OS\AGENTS.md` 与发布规范 `linxira-os/docs/RELEASE_STANDARD.md`;
> 本文只写本仓特有内容。

## 职责与边界

- 源自 Cachy-Update 与 Arch-Update,授权 `GPL-3.0-or-later`,保留上游历史与归属。
- 默认更新范围为**已安装的 pacman 仓库**;AUR 与 Flatpak 支持为 opt-in
  (经 `~/.config/linxira-update/linxira-update.conf`)。
- 名为 `linxira` 或以 `linxira-` 前缀的已安装外部包**绝不**发给 AUR helper;若无配置的 pacman 仓库提供它们,
  检查结果报 `incomplete`,而**不**声称系统已是最新。升级前仍提供 Arch Linux 新闻。
- **`EnableAutoApply`(默认关闭)= 全自动无人值守更新**:
  - 仅由无人值守服务 `linxira-update.service`(用户定时器上运行 `--check`)执行;
  - 仅当**所有安全门**通过时:root 为 btrfs、Timeshift 已配置(`linxira-config timeshift enable`)、
    `grub-btrfs-overlayfs` 在 mkinitcpio HOOKS 中、`grub-btrfsd` 已启用;
  - 先创建并**校验**一次专门的升级前 Timeshift 快照,快照失败则**拒绝**升级;
  - 托盘与交互式终端检查**始终**要求人工确认,与该选项无关;
  - 状态文件记录 `auto_apply` 结果与 `pre_snapshot_id` 回滚点;每次 pacman 事务也被
    `linxira-timeshift-autosnap.hook` 快照,可从 GRUB 菜单引导回滚。
- 只读状态对外原子发布于 `${XDG_STATE_HOME:-$HOME/.local/state}/linxira-update/status.json`;
  `check_status` 为 `ok` / `error` / `incomplete`,**消费者不得在非 `ok` 时把零更新数解读为"已最新"**。
- Linxira 的已签名包仓库与签名密钥须由 OS 发行方提供;本更新器**不猜测**仓库 URL、不启用包源。

## 目录布局

- `src/arch-update.sh`(主脚本,安装为 `linxira-update`)、`src/lib/`(库)
- `res/`:`icons/`、`desktop/`、`systemd/`(含 `linxira-update.preset`)、`completions/`、`config/`
- `po/`(翻译)、`doc/man/*.scd`(scdoc 源)、`test/`(`test/case/basic_functions.bats`、`test_*.py`)
- `Makefile`、`VERSION`、`README-LINXIRA.md`(权威 Linxira 说明)

## 本地校验

```sh
make build    # scdoc 生成 man 页 + msgfmt 生成 .mo
make test     # bats test/case/basic_functions.bats; python -m unittest discover -s test -p 'test_*.py'
```

CI(分支 `main` / `master`,python 3.13):

```sh
PYTHONPATH=src/lib python -m unittest discover -s test -v
bash -n src/arch-update.sh
```

命令面:`linxira-update` / `--check` / `--list` / `--tray` / `--gen-config`。

## 版本与发布

- 版本唯一来源是本仓根 `VERSION`(当前 `0.1.6`);源仓名 `arch-update`、包名 `linxira-update`、显示名 `Linxira-Update`。
- 改 `VERSION` 触发 `.github/workflows/release.yml`(分支 `main`)自动建 Release,进入 `[linxira]` 全自动链。**禁止手工 bump**。
- 落地状态以 `README-LINXIRA.md` 为准:当前工作树尚无下发通道,线上暂未提供无人值守更新能力。

## 禁区

- `EnableAutoApply` 的安全门与"快照失败即拒绝升级"不得削弱;托盘/交互式路径不得绕过人工确认。
- 不得把 `linxira` / `linxira-*` 外部包发给 AUR helper;不得在 `check_status != ok` 时输出"已最新"语义。
- 不得猜测/硬编码 Linxira 仓库 URL 或自动启用包源;不引入 `cachyos` / `aur` / `seafoam`;不直接 `sudo`/`su`/`doas`/`run0`。
- 不 `git add -A`。