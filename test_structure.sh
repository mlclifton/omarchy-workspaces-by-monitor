#!/usr/bin/env bash
# Fail if the tree is not a marketplace-shaped bar widget.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "fail: $*" >&2; exit 1; }

[[ -f LICENSE ]] || fail "LICENSE missing"
[[ -f README.md ]] || fail "README missing"
[[ -f BarWidget.qml ]] || fail "BarWidget.qml missing"
[[ -f preview.png ]] || fail "preview.png missing"
[[ -f manifest.json ]] || fail "manifest.json missing"

id=$(jq -r .id manifest.json)
[[ "$id" == "mlclifton.workspaces" ]] || fail "manifest id is $id"
[[ "$(jq -r .schemaVersion manifest.json)" == "1" ]] || fail "schemaVersion"
[[ "$(jq -r .entryPoints.barWidget manifest.json)" == "BarWidget.qml" ]] || fail "entryPoints"
jq -e '.omarchy.clonedFrom | not' manifest.json >/dev/null || fail "clonedFrom must be absent"

rg -q 'omarchy plugin remove mlclifton.workspaces' README.md || fail "README missing remove command"
rg -q 'omarchy plugin add https://github.com/mlclifton/omarchy-workspaces-by-monitor.git' README.md || fail "README missing add URL"
rg -q 'fork of \[jordanpartridge/omarchy-workspaces\]' README.md || fail "README missing upstream attribution"

if rg -q 'bar\.run\(|clonedFrom|moduleName: "omarchy' BarWidget.qml; then
  fail "forbidden strings in BarWidget.qml"
fi
rg -q 'moduleName: "mlclifton.workspaces"' BarWidget.qml || fail "moduleName mismatch"
# Workspace switching must go through Hyprland IPC, never a shelled-out command.
# Hyprland 0.56+ parses dispatch arguments as Lua, so the legacy "workspace N"
# string is a syntax error on the wire and silently does nothing.
rg -q 'Hyprland\.dispatch\(' BarWidget.qml || fail "expected Hyprland.dispatch"
rg -q 'hl\.dsp\.focus' BarWidget.qml || fail "expected the Lua workspace dispatcher"
rg -q 'Hyprland\.dispatch\("workspace ' BarWidget.qml && fail "legacy dispatch syntax is a no-op on Hyprland 0.56+"
# Right-click opens a free workspace on the pill's own monitor. There is no
# hl.dsp.focusmonitor; monitor focus is hl.dsp.focus({ monitor = ... }).
rg -q 'hl\.dsp\.focus\(\{ monitor' BarWidget.qml || fail "expected the monitor focus dispatcher"
rg -q 'hl\.dsp\.focusmonitor' BarWidget.qml && fail "hl.dsp.focusmonitor does not exist"

# WidgetButton.text must be a closed pill, not compositor strings.
rg -q 'function pillText' BarWidget.qml || fail "pillText missing"

echo ok
