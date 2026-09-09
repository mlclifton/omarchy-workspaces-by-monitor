# Implementation notes

Working notes for this Omarchy bar widget. It installs as plugin id
`mlclifton.workspaces`, renamed from upstream's `jordan.workspaces` so the two can be
installed side by side. That id is the single source of truth: `Bar.qml` overwrites a
widget's own `moduleName` with the id from the bar config entry
(`~/.config/omarchy/shell.json`, `bar.layout.<region>[].id`), and `canonicalWidgetId()`
is the identity function. Change the id and the manifest, the `moduleName` line, the
README commands, `test_structure.sh`'s pins and every installed config naming it must all
move together.

**This file exists to prime a coding agent's context.** Read it before touching
anything: it records what a full repo review would otherwise have to rediscover
from scratch every session — where the host shell lives, which bindings are
load-bearing, and the failures that cost real time to diagnose. Reading it is
meant to replace that review, not supplement it. Keep it current when behaviour
changes; a stale note here is worse than no note. It is not user documentation —
that is `README.md`.

Repos, as the remotes are named in a working clone:

- `origin` — https://github.com/mlclifton/omarchy-workspaces-by-monitor — this
  repo, the fork's own line of development.
- `upstream` — https://github.com/jordanpartridge/omarchy-workspaces — the
  original widget.
- `fork` — https://github.com/mlclifton/omarchy-workspaces — the GitHub fork,
  kept only to carry the `active-workspace-parens` branch behind upstream PR #1.

Keep this file off any branch aimed at `upstream`; it describes the fork.

## Shape of the thing

The entire widget is `BarWidget.qml`. `manifest.json` points at it (`entryPoints.barWidget`)
and is what `omarchy plugin` reads. No build step, no dependencies beyond Omarchy's own
Quickshell shell.

The host shell lives at `/usr/share/omarchy/shell` — read it rather than guessing at
`BarWidget`, `WidgetButton`, `Style`, or the `Hyprland` singleton. Two files carry almost
everything this widget depends on:

- `/usr/share/omarchy/shell/Ui/WidgetButton.qml` — the pill
- `/usr/share/omarchy/shell/Commons/Style.qml` — `space()` / `spaceReal()` scaling

## Data flow

`buildItems()` is the whole model. It returns a **flat** array that the `Repeater` renders
in order, with two item kinds:

| kind | fields | renders |
| --- | --- | --- |
| `ws` | `ws`, `monitor`, `tag`, `onScreen` | the workspace number |
| `sep` | — | `\|` between monitor groups |

Ordering: monitors sorted left-to-right then top-to-bottom (`sortedMonitors()`), each group
being its workspace ids ascending, `|` between groups.

`monitorTag()` still runs — `L`/`R`/`T`/`B` for exactly two monitors, else `1`,`2`,`3`… — but
its output is **tooltip-only** now (`monitorPhrase()` → "left screen" / "screen 2"). It never
reaches a pill, so it never goes through `pillText()`. There used to be a third `label` kind
that rendered the tag as its own pill at the head of each group; it was removed because the
leading number read as just another workspace number.

`items` (the property, not the function) opens with a deliberate `sink` loop that touches
`focusedId` and every monitor's `activeWorkspace.id`. That is not dead code — it is what
makes the QML binding re-evaluate when you switch workspaces. **Anything new that
`buildItems()` depends on must be touched there too, or the bar silently stops updating.**

## Two different notions of "current"

Easy to conflate; they are not the same:

- `onScreen` (per item, from `buildItems()`) — this workspace is the active one **on its own
  monitor**. Every monitor has one.
- `isThis` (per delegate, from `thisMonitorName`) — this item's monitor is the monitor **this
  bar instance is drawn on**. Each monitor runs its own bar, so the same model renders
  differently on each.

From those: `there = onScreen && !isThis` → `[8]`, and `here = onScreen && isThis` → `(5)`.
`root.focusedId` (the globally focused workspace, one across all monitors) is deliberately
*not* used for display — only as the change-trigger sink above. A future "mark the truly
focused workspace" feature would need it, and would have to settle precedence against the
bracket rule.

`thisMonitorName` resolves through three fallbacks (bar module slot → `Hyprland.monitorFor`
→ `window.screen.name`). If all three fail it is `""`, `isThis` is false everywhere, and every
active workspace renders as `[n]` with nothing parenthesised. Degraded but harmless.

## Gotchas that cost time

1. **`pillText()` is a closed whitelist.** Every string reaching `WidgetButton.text` goes
   through `^[0-9|()[\]]{1,8}$` and returns `""` on a miss. Add a new glyph to a pill and
   you must add it to that character class, or the pill just renders blank with no error
   anywhere. This is intentional — it stops compositor-supplied strings reaching the label.
2. **The label is not elided or clipped.** `WidgetButton`'s `Text` is `anchors.centerIn`
   with no `elide`, so an under-wide `fixedWidth` makes pills *overlap their neighbours*
   rather than truncate. Widths are `Style.space(10)` for `sep`, `Style.space(28)` for
   two-glyph-wrapped pills (`there || here`), `Style.space(20)` for plain.
3. **Slot width changes shift the row.** A workspace switch swaps a 20px slot for a 28px
   one, so the group jitters horizontally. Pre-existing with brackets; parens add a second
   instance. Pin every `ws` pill to 28 if it ever needs to stop.
4. **Vertical bars ignore all of that** — `fixedWidth` becomes `barSize`, so wrapped pills
   can overflow a narrow vertical bar. Also pre-existing.
5. **`Style.space()` is theme-scaled**, not pixels. Never hardcode a number.

## Testing loop

The installed copy is a plain git checkout at `~/.config/omarchy/plugins/mlclifton.workspaces`
— the directory is named for the plugin id, not the repo. **Check what it tracks before
trusting it**: `git -C ~/.config/omarchy/plugins/mlclifton.workspaces remote -v` should be
this repo. A directory left tracking upstream restores *upstream's* widget on any
`git checkout` or `omarchy plugin update` — no parens, the monitor label pills back, and
clicking a pill silently doing nothing.

There is no `omarchy plugin` dev-link subcommand, so iterating means copying over it:

```bash
cp BarWidget.qml ~/.config/omarchy/plugins/mlclifton.workspaces/BarWidget.qml
omarchy restart shell
```

That leaves the installed checkout dirty, which makes `omarchy plugin update
mlclifton.workspaces` fail until you revert — and the revert restores whatever that checkout
tracks, so make sure that is `origin` and not upstream:

```bash
git -C ~/.config/omarchy/plugins/mlclifton.workspaces checkout BarWidget.qml && omarchy restart shell
```

Verify visually — QML binding bugs do not throw, they just render nothing. Each monitor has
its own bar, and the whole point of `isThis` is that they differ, so screenshot **all** of
them:

```bash
hyprctl monitors -j | python3 -c "import json,sys;[print(m['name'],m['x'],m['y'],m['focused'],m['activeWorkspace']['name']) for m in json.load(sys.stdin)]"
grim -g "0,0 900x44" /tmp/bar.png        # x,y from the monitor's own origin; bar is the top strip
```

This machine is three monitors — `HDMI-A-1` at x=-1920, `DP-1` at x=0 (primary), `DP-2` at
x=3440, the latter two at y=-20. Three monitors means numeric tags (`screen 1/2/3` in the
tooltips), so the `L/R` two-monitor path is **not** exercised here; reason about it by reading
`monitorTag()`.

Structural checks, both fast and worth running before any commit:

```bash
./test_structure.sh          # greps for pillText, moduleName, the Lua dispatcher,
                             # and the README's install URL + upstream attribution
omarchy plugin validate .    # manifest against the plugin schema
```

`test_structure.sh` will fail the build if `bar.run(`, `clonedFrom`, or a `moduleName:
"omarchy` prefix appears in the QML — the marketplace rules for a third-party plugin.

## House style

Zero comments in `BarWidget.qml`, and the existing code is deliberate about it. Defensive
`Number()`/regex validation on anything crossing the compositor boundary, hard caps
(`maxMonitors`, `maxScan`, `maxItems`) on every loop, `readonly property` for derived state,
`var` and C-style `for` loops rather than modern JS. Match it.

## Workspace previews

Hovering a `ws` pill opens a monitor-shaped thumbnail of that workspace. The
widget draws none of it. The thumbnail comes from a service whose source lives
in its own repo at `~/Projects/omarchy-workspace-thumbnails`
(https://github.com/mlclifton/omarchy-workspace-thumbnail-svc), whose
`IMPLEMENTATION.md` is the place to look for anything about the thumbnail itself.

### Why the service lives here

`thumbnails/` is a **vendored copy** of that repo, mounted under *this* plugin's
id. Do not edit it directly — change the source repo and re-run its
`install.sh`, which copies the files across and checks this manifest.

It used to be a separate plugin, `mlclifton.workspace-thumbnails`, reached with
`serviceFor("mlclifton.workspace-thumbnails")`. Omarchy 4.0.3 ended that.
Third-party entry points now receive a capability-scoped facade instead of the
shell root, and its `serviceFor` calls `pluginOwnsTarget` first: only the
**caller's own id** resolves, and anything else returns null silently. That
came in as a security fix (upstream PR 9618), because the same unscoped
injection also exposed `omarchy.lock` and `omarchy.polkit`.

So the service ships inside this plugin, the manifest declares both
`bar-widget` and `service` kinds, and the widget looks up itself. If you split
it back out, hover previews stop working and nothing logs an error.

The wiring in `BarWidget.qml`:

- `thumbnails` resolves the service through
  `root.bar.shell.serviceFor("mlclifton.workspaces")` — **this plugin's own id**.
  `bar.shell` is injected by `shell.qml` (`shell: shell` on the `Bar`).
  It is `null` if the vendored `thumbnails/` directory or the manifest's
  `entryPoints.service` is missing. A `plugins[]` entry in `shell.json` is *not*
  needed: a bar-layout entry already counts as enabled.
- `requestPreview` calls `thumbnails.refreshWallpaper()` before opening. The
  service can no longer reach `omarchy.background` either, so nothing tells it
  the theme changed and it re-reads the symlink on demand instead.
- `requestPreview` / `leavePreview` / `openPreview` / `closePreview` plus
  `previewOpenTimer` (120ms) and `previewCloseTimer` (200ms).
- A `Loader` holding a `PopupCard`, sized `Style.space(300)` wide by
  `300 / previewAspect` so the card follows each monitor's shape.
- A `Connections` on each pill's `tooltipHovered`, gated on `isWs` so `sep`
  pills keep their tooltip and open nothing.

Four things that will bite:

1. **Everything degrades to null-safe.** If `thumbnails` is null, `requestPreview`
   returns immediately and the widget behaves exactly as it did before. Keep it
   that way — the widget must stay useful if the vendored service fails to load.
   This is also why the breakage above was silent for so long.
2. **The tooltip races the preview.** `WidgetButton`'s `MouseArea.onEntered`
   calls `bar.showTooltip`, and that can land *after* `requestPreview`'s
   `hideTooltip`, leaving the tooltip painted over the card. Hiding it again in
   `openPreview()` (after the 120ms timer) is what actually fixes it. Verified
   by screenshot; do not "simplify" that second `hideTooltip` away.
3. **`PopupCard` registers itself as the bar's active popout**, which makes the
   bar draw an accent "open panel" underline and closes other popouts. A hover
   preview is not a panel, so `onOpenChanged` releases the registration via
   `bar.releasePopout(coordinatorKey)` on the next tick.
4. **Click-to-focus needs the Lua dispatcher.** See the section below.

## Workspace switching must use the Lua dispatcher

`focusWorkspace()` sends:

```qml
Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + n + "\" })")
```

**Not** the legacy `Hyprland.dispatch("workspace " + n)`. Hyprland 0.56+ parses
dispatch arguments as Lua, so the legacy string is a syntax error on the wire.
It fails *silently from the widget's point of view* — clicking a pill simply did
nothing. Confirmed at three levels:

```bash
# 1. the raw IPC socket
printf '/dispatch workspace 3' | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock
#   error: [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
printf '/dispatch hl.dsp.focus({ workspace = "3" })' | socat - UNIX-CONNECT:...
#   ok
```

2. Through Quickshell's own `Hyprland.dispatch()` in a throwaway shell
   (`quickshell -p file.qml`), which proves the braces and escaped quotes travel
   verbatim: the Lua form switches workspace, the legacy form logs
   `quickshell.hyprland.ipc: Dispatch request "workspace 4" failed`.
3. By clicking a pill.

That warning goes to the journal, so `journalctl --user | grep hyprland.ipc` is
the fastest way to catch a regression here.

`test_structure.sh` now pins all of this: it requires `Hyprland.dispatch(` and
`hl.dsp.focus`, and **fails** if the legacy `Hyprland.dispatch("workspace ` form
reappears.

Two things to keep in mind:

- **The numeric validation in `focusWorkspace()` is now load-bearing twice
  over.** `n` is interpolated into a Lua expression, so the existing
  `Number()` / integer / range checks are what stop a compositor-supplied value
  reaching the Lua interpreter. Do not relax them.
- **This drops support for Hyprland < 0.56.** Fine for Omarchy 4.0.2, which
  ships 0.56.2, but upstream may want a version guard before merging. There is
  no clean runtime fallback: `Hyprland.dispatch()` is fire-and-forget, so a
  failed dispatch cannot be detected and retried in the other syntax.

## Right-click opens a free workspace

Right-clicking a `ws` pill allocates the lowest unused id (1..`maxWorkspaceId`) to
**that pill's monitor** and switches to it. `WidgetButton` already accepts all three
buttons and emits `pressed(int button)` — the handler takes the argument and branches
on `Qt.RightButton`; `pressable: isWs` is what keeps `sep` pills out of it.

Two dispatches, in this order:

```qml
Hyprland.dispatch("hl.dsp.focus({ monitor = \"" + name + "\" })")
Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + n + "\" })")
```

Hyprland creates a workspace on whatever monitor is focused, so focusing the monitor
first is what binds the new workspace to the right screen. **There is no
`hl.dsp.focusmonitor`** — it is a nil field and the dispatch errors on the wire, the
same silent failure as the legacy syntax. The Lua API is namespaced
(`hl.dsp.focus`, `hl.dsp.window.*`, `hl.dsp.workspace.*`); read
`/usr/share/hypr/stubs/hl.meta.lua` for the field list rather than guessing, and note
it types every dispatcher as `fun(...)`, so the accepted table keys are not documented
there — probe them with `hyprctl dispatch`.

`nextFreeWorkspace()` counts an id as used if a workspace with that id exists at all.
Hyprland destroys an empty workspace when you leave it, so existing ids are in use;
returns `-1` when 1..10 are all taken, and `openFreeWorkspace()` then does nothing.
`connectorName()` validates the monitor before it reaches the Lua string, the same
load-bearing role the numeric checks play in `focusWorkspace()`.

## History

- `e3d5e21` upstream tip when this fork was taken.
- `active-workspace-parens` → upstream PR #1: parenthesise the workspace this screen is
  showing. Touched `pillText()`'s whitelist, added `here` to the delegate, widened the slot,
  updated README + manifest `description`. Version left at 1.0.0 for the maintainer to own;
  `preview.png` left stale (shows `L [1] 4 | R 8`, would now be `L [1] 4 | R (8)`).
- `7fad7c7` (2026-09-08) wired hover previews to `mlclifton.workspace-thumbnails`.
- (2026-09-09) previews stopped rendering after an update to Omarchy 4.0.3, which
  restricted `serviceFor` to the caller's own plugin id. The thumbnail service is
  now vendored into `thumbnails/` and mounted under this plugin's id, and the
  manifest gained the `service` kind. See "Why the service lives here".
- `6e83421` (2026-09-08) fixed click-to-focus: legacy `workspace N` dispatch is a no-op on
  Hyprland 0.56+; switched to `hl.dsp.focus`, pinned by `test_structure.sh`.
- `f82d694` (2026-09-08) dropped the per-monitor `label` pill. The tag pill led each group
  (`1 [1] | 2 2 (5) | 3 [3]`) and was indistinguishable from a workspace number;
  now `[1] | 2 (5) | [3]`, groups separated by `|` alone. Removed `isLabel` from
  the delegate, the `label` branch of `tooltipFor()`, and `LRTB` from `pillText()`'s
  whitelist. README example updated. `preview.png` regenerated from a live DP-1
  grab (`grim` the bar band `y 0..23`, crop to the pill run, pad to the bar's own
  `rgb(10,3,20)`, Lanczos 3x) — 408x120, now `[1] | 2 (5) | [3]`.
- `2026-09-08` split the repos. `main` here is the fork's own line
  (`origin`, the standalone repo); `active-workspace-parens` stays pinned at
  `ad14084` to match open upstream PR #1 on the `fork` remote; `lua-dispatch-fix`
  holds `6e83421` cherry-picked onto `upstream/main` for a possible PR #2. The
  plugin id was still `jordan.workspaces` at that point, renamed in the entry
  below.
- `2026-09-08` renamed the plugin id `jordan.workspaces` → `mlclifton.workspaces`,
  so this widget and upstream's can be installed side by side. Manifest `id`,
  `moduleName`, the README commands and `test_structure.sh`'s pins moved together;
  on this machine the `shell.json` bar entry was repointed and the plugin
  reinstalled from `origin` under the new directory.
- `2026-09-08` right-click on a pill opens the next unused workspace on that
  pill's monitor. Verified the dispatch pair by hand over `hyprctl`, then from
  inside the widget with a throwaway `Timer` calling `openFreeWorkspace("DP-2")`,
  which is the only way to exercise the QML path without a synthetic click.
  Nothing on this machine can synthesise a right-click (`wtype` is keyboard
  only), so the `Qt.RightButton` branch itself was never machine-verified —
  confirm it by hand after any change to the press handler.
