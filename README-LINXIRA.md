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
