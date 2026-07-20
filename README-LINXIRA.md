# Linxira Update

Linxira Update is the system update notifier and maintenance assistant for
Linxira OS. It provides an interactive terminal workflow, a Qt system tray
applet, and a systemd user timer.

The default update scope is the installed pacman repositories. AUR and Flatpak
support are opt-in through `~/.config/linxira-update/linxira-update.conf`.

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

This project is derived from Cachy-Update and Arch-Update and remains licensed
under GPL-3.0-or-later. Upstream history and attribution are preserved in the
repository.
