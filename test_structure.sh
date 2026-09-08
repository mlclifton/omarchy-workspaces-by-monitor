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
[[ "$id" == "jordan.workspaces" ]] || fail "manifest id is $id"
[[ "$(jq -r .schemaVersion manifest.json)" == "1" ]] || fail "schemaVersion"
[[ "$(jq -r .entryPoints.barWidget manifest.json)" == "BarWidget.qml" ]] || fail "entryPoints"
jq -e '.omarchy.clonedFrom | not' manifest.json >/dev/null || fail "clonedFrom must be absent"

rg -q 'omarchy plugin remove jordan.workspaces' README.md || fail "README missing remove command"
rg -q 'omarchy plugin add https://github.com/jordanpartridge/omarchy-workspaces.git' README.md || fail "README missing add URL"

if rg -q 'bar\.run\(|clonedFrom|moduleName: "omarchy' BarWidget.qml; then
  fail "forbidden strings in BarWidget.qml"
fi
rg -q 'moduleName: "jordan.workspaces"' BarWidget.qml || fail "moduleName mismatch"
rg -q 'Hyprland.dispatch\("workspace "' BarWidget.qml || fail "expected Hyprland.dispatch"

# WidgetButton.text must be a closed pill, not compositor strings.
rg -q 'function pillText' BarWidget.qml || fail "pillText missing"

echo ok
