# Workspaces by monitor

The stock Omarchy bar repeats 1–5 on every screen and only marks the focused workspace. On two monitors you cannot tell which number lives where.

This widget groups the numbers by screen:

```
L 2 4 | R 1 [8]
```

- **L / R** (or **T / B** if the screens are stacked) is the monitor
- A plain number in this bar's group is where you are
- `[8]` is what the other screen is showing
- A dim number is on that monitor, not showing

Click a number to focus that workspace. Super+N from Hyprland still works as usual.

## Install

```bash
omarchy plugin add https://github.com/jordanpartridge/omarchy-workspaces.git
omarchy plugin enable jordan.workspaces
```

Take `omarchy.workspaces` off the bar if both switchers are showing.

Plugins run as unsandboxed code inside `omarchy-shell`. Review the tree before enabling. The installer only clones files; it does not run helpers or sudo.

Requires Omarchy's Hyprland bar (Quickshell). No extra packages.

## Removing

```bash
omarchy plugin remove jordan.workspaces
```

This plugin writes no state, cache, credentials, units, or hooks. Nothing survives removal except a git checkout you made yourself outside Omarchy.

## License

MIT
