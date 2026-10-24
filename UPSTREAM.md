# Upstream and local changes

`linxira-update` is a modified version of **Arch-Update** by Antiz96.
This file records the upstream, the license, and what Linxira changed, so the
GPL-3.0-or-later obligations (§5(a): prominent notices of modified files; §6:
source availability) are met.

| Item | Value |
|---|---|
| Upstream | <https://github.com/Antiz96/arch-update> |
| Upstream license | GPL-3.0-or-later (see `LICENSE`) |
| Copyright | Copyright (C) Antiz96 and Arch-Update contributors |
| Source of this version | this repository (public, full history) |

## Changes by Linxira OS

- Renamed the product and commands to `linxira-update` (upstream: `arch-update`);
  configuration, state and notification names follow the same rename.
- Rebranded user-visible strings and desktop entries; no upstream translations
  were removed.
- Uses the Linxira OS update-status contract (`/var/lib/linxira/update-status.json`)
  for the welcome app and the tray.
- Packaging lives in `Linxira-OS/packages` (`linxira-update` PKGBUILD), which
  builds from a pinned commit of this repository.

Every modified source file carries a header line
`Modified by Linxira OS contributors (2026-10-24); see UPSTREAM.md`.
