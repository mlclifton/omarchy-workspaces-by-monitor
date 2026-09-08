import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jordan.workspaces"

  readonly property int maxMonitors: 8
  readonly property int maxWorkspaceId: 10
  readonly property int maxScan: 64
  readonly property int maxItems: 48
  readonly property int maxTooltip: 48

  readonly property var hostWindow: QsWindow.window
  readonly property var thisMonitor: {
    var win = root.hostWindow
    if (!win || !win.screen || typeof Hyprland.monitorFor !== "function") return null
    return Hyprland.monitorFor(win.screen)
  }
  readonly property string thisMonitorName: {
    var name = ""
    if (root.bar && root.bar.moduleSlots && typeof root.bar.slotScreenName === "function") {
      var slots = root.bar.moduleSlots
      var cap = Math.min(slots.length, 16)
      for (var i = 0; i < cap; i++) {
        if (slots[i] && slots[i].activeItem === root) {
          name = root.connectorName(root.bar.slotScreenName(slots[i]))
          if (name !== "") return name
        }
      }
    }
    if (root.thisMonitor && root.thisMonitor.name)
      return root.connectorName(root.thisMonitor.name)
    var win = root.hostWindow
    if (win && win.screen && win.screen.name)
      return root.connectorName(win.screen.name)
    return ""
  }
  readonly property var workspaceValues: Hyprland.workspaces.values
  readonly property var monitorValues: Hyprland.monitors.values
  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  readonly property var items: {
    var sink = root.focusedId
    var monitors = root.monitorValues
    var cap = Math.min(monitors.length, root.maxMonitors)
    for (var i = 0; i < cap; i++) {
      var aw = monitors[i].activeWorkspace
      if (aw) sink += aw.id
    }
    return root.buildItems()
  }

  function plain(value) {
    return String(value || "").replace(/[<>&]/g, "").replace(/[\x00-\x1F\x7F]/g, "").slice(0, root.maxTooltip)
  }

  function connectorName(value) {
    var name = String(value || "")
    if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{0,31}$/.test(name)) return ""
    return name
  }

  function pillText(value) {
    var text = String(value || "")
    if (!/^[0-9LRTB|()[\]]{1,8}$/.test(text)) return ""
    return text
  }

  function workspaceById(id) {
    var values = root.workspaceValues
    var cap = Math.min(values.length, root.maxScan)
    for (var i = 0; i < cap; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function sortedMonitors() {
    var list = []
    var values = root.monitorValues
    var cap = Math.min(values.length, root.maxMonitors)
    for (var i = 0; i < cap; i++) {
      var mon = values[i]
      if (!mon || !root.connectorName(mon.name)) continue
      list.push(mon)
    }
    list.sort(function(left, right) {
      var dx = (left.x || 0) - (right.x || 0)
      if (dx !== 0) return dx
      return (left.y || 0) - (right.y || 0)
    })
    return list
  }

  function monitorTag(index, monitors) {
    if (monitors.length === 2) {
      var dx = Math.abs((monitors[1].x || 0) - (monitors[0].x || 0))
      var dy = Math.abs((monitors[1].y || 0) - (monitors[0].y || 0))
      if (dy > dx) return index === 0 ? "T" : "B"
      return index === 0 ? "L" : "R"
    }
    if (index < 0 || index > 8) return ""
    return String(index + 1)
  }

  function monitorPhrase(tag) {
    if (tag === "L") return "left screen"
    if (tag === "R") return "right screen"
    if (tag === "T") return "top screen"
    if (tag === "B") return "bottom screen"
    return "screen " + tag
  }

  function buildItems() {
    var monitors = root.sortedMonitors()
    var values = root.workspaceValues
    var idsByName = Object.create(null)
    var i
    var scan = Math.min(values.length, root.maxScan)

    for (i = 0; i < monitors.length; i++) idsByName[root.connectorName(monitors[i].name)] = []

    for (i = 0; i < scan; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id < 1 || id > root.maxWorkspaceId) continue
      var mon = workspace.monitor
      var name = mon ? root.connectorName(mon.name) : ""
      if (name === "") continue
      if (!idsByName[name]) idsByName[name] = []
      if (idsByName[name].length >= root.maxWorkspaceId) continue
      idsByName[name].push(id)
    }

    var out = []
    var shown = 0
    for (i = 0; i < monitors.length; i++) {
      if (out.length >= root.maxItems) break
      var monName = root.connectorName(monitors[i].name)
      var ids = idsByName[monName] || []
      if (ids.length === 0) continue
      ids.sort(function(left, right) { return left - right })
      var tag = root.monitorTag(i, monitors)
      var activeWs = monitors[i].activeWorkspace
      var activeId = activeWs ? activeWs.id : -1
      if (shown > 0) out.push({ kind: "sep" })
      out.push({ kind: "label", text: tag, monitor: monName })
      for (var n = 0; n < ids.length; n++) {
        if (out.length >= root.maxItems) break
        out.push({
          kind: "ws",
          ws: ids[n],
          monitor: monName,
          tag: tag,
          onScreen: ids[n] === activeId
        })
      }
      shown += 1
    }
    return out
  }

  function focusWorkspace(id) {
    var n = Number(id)
    if (n !== n || n < 1 || n > root.maxWorkspaceId || Math.floor(n) !== n) return
    Hyprland.dispatch("workspace " + n)
  }

  function tooltipFor(item) {
    if (!item) return ""
    var isThis = item.monitor && root.thisMonitorName !== "" && item.monitor === root.thisMonitorName
    if (item.kind === "label") {
      var here = isThis ? "this screen · " : ""
      return root.plain(here + root.monitorPhrase(item.text))
    }
    if (item.kind !== "ws") return ""
    var where = isThis ? "this screen" : root.monitorPhrase(item.tag)
    var conn = root.connectorName(item.monitor)
    if (conn !== "") where += " · " + conn
    if (isThis && item.onScreen) where += " · you are here"
    else if (item.onScreen) where += " · on that screen now"
    return root.plain(where)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.items.length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.items

      WidgetButton {
        required property var modelData

        readonly property bool isSep: modelData && modelData.kind === "sep"
        readonly property bool isLabel: modelData && modelData.kind === "label"
        readonly property bool isWs: modelData && modelData.kind === "ws"
        readonly property int workspaceId: isWs ? Number(modelData.ws) : 0
        readonly property var workspace: isWs ? root.workspaceById(workspaceId) : null
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool onScreen: isWs && modelData.onScreen === true
        readonly property bool isThis: {
          var mon = modelData && modelData.monitor ? root.connectorName(modelData.monitor) : ""
          return mon !== "" && root.thisMonitorName !== "" && mon === root.thisMonitorName
        }
        readonly property bool there: onScreen && !isThis
        readonly property bool here: onScreen && isThis
        readonly property string numberText: workspaceId === 10 ? "0" : String(workspaceId)

        bar: root.bar
        text: {
          if (isSep) return root.pillText("|")
          if (isLabel) return root.pillText(modelData.text)
          if (there) return root.pillText("[" + numberText + "]")
          if (here) return root.pillText("(" + numberText + ")")
          return root.pillText(numberText)
        }
        active: false
        dimmed: isSep || (isLabel && !isThis)
        opacity: isSep ? 0.45 : (isLabel ? 1 : (occupied || onScreen ? 1 : 0.5))
        pressable: isWs
        interactive: isWs || isLabel
        tooltipText: root.tooltipFor(modelData)
        horizontalMargin: isSep ? 2 : 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : (isSep ? Style.space(10) : (there || here ? Style.space(28) : Style.space(20)))
        fixedHeight: root.barSize
        onPressed: function() {
          if (isWs) root.focusWorkspace(workspaceId)
        }
      }
    }
  }
}
