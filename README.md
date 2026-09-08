# Workspaces by monitor

*A fork of [jordanpartridge/omarchy-workspaces](https://github.com/jordanpartridge/omarchy-workspaces) — see [Fork](#fork) for what differs.*

The stock Omarchy bar repeats 1–5 on every screen and only marks the focused workspace. On two monitors you cannot tell which number lives where.

This widget groups the numbers by screen:

```
(2) 4 | 1 [8]
```

- `|` separates one screen's workspaces from the next, left to right
- `(2)` is the workspace this screen is showing, the one you are looking at
- A plain number is another workspace on this screen
- `[8]` is what the other screen is showing
- A dim number is on that monitor, not showing

Click a number to focus that workspace. Super+N from Hyprland still works as usual.

## Install

```bash
omarchy plugin add https://github.com/mlclifton/omarchy-workspaces-by-monitor.git
omarchy plugin enable jordan.workspaces
```

Take `omarchy.workspaces` off the bar if both switchers are showing.

Plugins run as unsandboxed code inside `omarchy-shell`. Review the tree before enabling. The installer only clones files; it does not run helpers or elevate.

Requires Omarchy's Hyprland bar (Quickshell). No extra packages.

## Removing

```bash
omarchy plugin remove jordan.workspaces
```

This plugin writes no state, cache, credentials, units, or hooks. Nothing survives removal except a git checkout you made yourself outside Omarchy.

## Fork

This is a fork of [jordanpartridge/omarchy-workspaces](https://github.com/jordanpartridge/omarchy-workspaces). The original widget is Jordan Partridge's work, MIT-licensed; what follows is what this fork changes.

- No per-monitor tag pill. Upstream leads each group with `L`/`R` (or `1`/`2`/`3`), which reads as another workspace number; here `|` alone separates the screens.
- Parentheses mark the workspace this screen is showing. Proposed back upstream as PR #1.
- Clicking a pill works on Hyprland 0.56+. Dispatch arguments are parsed as Lua there, so upstream's `workspace N` is a syntax error on the wire and fails silently.
- Optional hover previews. With [omarchy-workspace-thumbnail-svc](https://github.com/mlclifton/omarchy-workspace-thumbnail-svc) installed and enabled, hovering a pill shows a thumbnail of that workspace. Without it the widget behaves exactly as it does here.

It still declares the plugin id `jordan.workspaces`, so install this or upstream's, not both.

## License

MIT
