import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Two numbering schemes, one widget:
  //
  //   "monitor"  Omarchy's per-monitor workspaces (the default since 4.5).
  //              Every monitor has workspaces 1-10 of its own, which Hyprland
  //              numbers in a block of ten per monitor: 1-10, 11-20, and so on
  //              (see default/hypr/monitor-workspaces.lua). Each bar shows its
  //              own monitor's block, numbered 1-10.
  //
  //   "global"   Plain Hyprland numbering, with workspaces pinned to monitors
  //              by workspace rules (hl.workspace_rule({ workspace = "8",
  //              monitor = "HDMI-A-1" })). Each bar shows the workspaces pinned
  //              to its monitor, plus any other that is on it right now.
  //
  //   "auto"     (default) "global" when Hyprland has rules pinning numbered
  //              workspaces to monitors, "monitor" otherwise.
  //
  // Settings, in this widget's shell.json entry:
  //   "numbering": "auto" | "monitor" | "global"
  //   "labels":    { "10": "G" }   text for a workspace instead of its number
  //                               (keyed by id in global mode, slot otherwise)
  readonly property string numbering: {
    var mode = String(root.setting("numbering", "auto"))
    if (mode === "global" || mode === "monitor") return mode
    return root.hasPins ? "global" : "monitor"
  }
  readonly property bool global: root.numbering === "global"
  readonly property var labels: root.setting("labels", ({}))

  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // ---- Global numbering: monitor name -> pinned workspace ids, from Hyprland's
  // workspace rules. Read again on every config reload.
  property var pins: ({})
  property bool hasPins: false

  function readRules(text) {
    var next = {}
    var any = false
    var rules = []
    try { rules = JSON.parse(text) } catch (e) { rules = [] }
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i]
      var name = rule ? String(rule.workspaceString || "") : ""
      if (!rule || !rule.monitor || !/^[0-9]+$/.test(name)) continue
      var id = parseInt(name, 10)
      if (id <= 0) continue
      if (!next[rule.monitor]) next[rule.monitor] = []
      if (next[rule.monitor].indexOf(id) === -1) next[rule.monitor].push(id)
      any = true
    }
    root.pins = next
    root.hasPins = any
  }

  Process {
    id: rulesProc
    command: ["hyprctl", "workspacerules", "-j"]
    stdout: StdioCollector {
      onStreamFinished: root.readRules(text)
    }
  }

  // ---- Per-monitor numbering: connector -> block, from the file Hyprland keeps
  // them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function isGuest(id) {
    return !root.global && root.blockOf(id) !== root.block
  }

  // Global: the workspaces pinned to this monitor, except one that is on
  // another monitor right now (a script moved it there), and any other
  // workspace that is on this monitor.
  function globalIds() {
    var ids = []
    var pinned = root.pins[root.monitorName] || []

    for (var p = 0; p < pinned.length; p++) {
      var workspace = root.workspaceById(pinned[p])
      var elsewhere = workspace !== null && workspace.monitor !== null && workspace.monitor.name !== root.monitorName
      if (!elsewhere) ids.push(pinned[p])
    }

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && values[i].monitor && values[i].monitor.name === root.monitorName && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Per monitor: all ten of the monitor's own. After them come workspaces that
  // are only visiting: those of a monitor that is unplugged, which had no room
  // to join this one's.
  function monitorIds() {
    var base = root.block * root.slots
    var ids = []
    for (var s = 1; s <= root.slots; s++) ids.push(base + s)
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function workspaceIds() {
    return root.global ? root.globalIds() : root.monitorIds()
  }

  function label(id) {
    var key = root.global || root.isGuest(id) ? id : root.slotOf(id)
    var custom = root.labels ? root.labels[String(key)] : undefined
    if (custom !== undefined && custom !== null && custom !== "") return String(custom)
    return key === root.slots ? "0" : String(key)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (!root.global && root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  // A wheel notch moves one entry along the row, and a touchpad adds up its
  // smaller deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    // Holds at either end rather than wrapping, so a touchpad swipe that runs
    // long stops on the last workspace.
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // Clicking the workspace a monitor shows cycles its layout (tiling,
  // scrolling, floating), as Super + L does. The layout commands act on the
  // focused workspace, so a click on another monitor's bar focuses that
  // monitor first.
  function cycleLayout() {
    if (!root.bar) return
    var command = "omarchy-hyprland-workspace-layout-toggle"
    if (root.monitor && !root.monitor.focused) {
      command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + root.monitorName + "\" })") + " >/dev/null && " + command
    }
    root.bar.run(command)
  }

  Component.onCompleted: rulesProc.running = true

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded" && !rulesProc.running) rulesProc.running = true
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: button
        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property bool firstGuest: root.isGuest(modelData) && index > 0 && !root.isGuest(root.workspaceIds()[index - 1])

        // A gap sets visiting workspaces apart from the monitor's own.
        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        bar: root.bar
        // The shown workspace keeps its number, drawn in the theme's accent
        // colour with an accent line under it. Workspaces with windows are
        // drawn in full, empty ones dimmed.
        text: root.label(modelData)
        active: shown
        activeColor: Color.accent
        opacity: occupied || shown ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() {
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        // Not rounded to a whole pixel: on a scaled display that rounding
        // pushes the line visibly off the centred number.
        Rectangle {
          visible: button.shown
          width: Math.round(button.fontSize * 0.9)
          height: Math.max(2, Math.round(button.fontSize / 7))
          radius: height / 2
          color: Color.accent
          x: (button.width - width) / 2
          y: Math.round(button.height / 2 + button.fontSize * 0.75)
        }
      }
    }
  }
}
