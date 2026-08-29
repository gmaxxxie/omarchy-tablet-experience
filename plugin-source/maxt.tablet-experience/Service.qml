import QtQuick
import Quickshell
import Quickshell.Io

// Tablet Experience — Laptop/Tablet state machine (Phases 7–10).
//
// Persistent state (survives shell reloads via PersistentProperties):
//   mode             "laptop" | "tablet"
//   tabletRotation   rotation preset applied when ENTERING tablet mode:
//                    "off" | "0" (landscape) | "2" (180° fold)
//   autoOrient       opt-in: follow iio-sensor-proxy orientation while in
//                    tablet mode (normal→0°, left-up→90°, bottom-up→180°,
//                    right-up→270°); overrides the manual/preset rotation
//   autoSwitchMode   opt-in: keyboard USB attach/detach (17ef:60fe) drives
//                    mode automatically (attached→laptop, detached→tablet)
//
// Side effects are applied idempotently; auto-orientation applies silently
// (no OSD), manual switches show OSD feedback.
//
// IPC (omarchy-shell maxt.tablet-experience <method>):
//   getState | getMode | toggle | setMode <laptop|tablet>
//   setRotation <off|0|2> | setAutoOrient <on|off> | setAutoSwitch <on|off>

Item {
  id: root

  Component.onCompleted: console.log("tablet-experience Service LOADED v2")

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string mode: persisted.mode
  readonly property bool isTabletMode: persisted.mode === "tablet"
  readonly property string tabletRotation: persisted.tabletRotation
  readonly property bool autoOrient: persisted.autoOrient
  readonly property bool autoSwitchMode: persisted.autoSwitchMode

  // Phase 9: last known folio-keyboard USB presence.
  property bool kbAttached: true
  property bool kbWasAttached: true
  property bool kbStateKnown: false

  // Phase 6: last orientation read + the transform we applied for it (so a
  // repeated read does nothing, and manual transforms are re-corrected).
  property string orientation: "unknown"
  property string appliedFor: ""

  PersistentProperties {
    id: persisted
    reloadableId: "maxt-tablet-experience"
    property string mode: "laptop"
    property string tabletRotation: "off"   // off | "0" | "2"
    property bool autoOrient: false
    property bool autoSwitchMode: false
  }

  // ------------------------------------------------------------- actions

  function toggleMode() {
    setMode(isTabletMode ? "laptop" : "tablet")
  }

  function setMode(next) {
    if (next !== "laptop" && next !== "tablet") return
    if (next === persisted.mode) return
    persisted.mode = next
    applyNext()
  }

  function cycleRotationPreset() {
    // off -> 2 (fold) -> 0 (landscape) -> off; 90/270 portrait is a manual
    // rotate-while-in-tablet decision, not a mode-exit default.
    var ring = ["off", "2", "0"]
    if (persisted.tabletRotation === "off") setRotationPreset("2")
    else if (persisted.tabletRotation === "2") setRotationPreset("0")
    else setRotationPreset("off")
  }

  function setRotationPreset(value) {
    if (["off", "0", "2"].indexOf(value) === -1) return
    persisted.tabletRotation = value
    osd("rotate-cw", "Tablet rotation: " + rotationLabel(value))
  }

  function rotationLabel(value) {
    if (value === "0") return "landscape 0°"
    if (value === "2") return "flipped 180°"
    return "off (manual)"
  }

  // Idempotent side-effect pass — only runs on real transitions.
  function applyNext() {
    osd("tablet", isTabletMode ? "Tablet mode" : "Laptop mode")
    if (!isTabletMode) return
    // With auto-orientation live, the sensor takes over immediately; the
    // preset would fight it a second later, so skip it.
    if (!persisted.autoOrient && persisted.tabletRotation !== "off") {
      rotateProcess.command = ["omarchy-rotate", persisted.tabletRotation]
      rotateProcess.running = true
    }
  }

  // Phase 6 — orientation → transform, only when enabled AND in tablet mode.
  // iio-sensor-proxy convention:
  //   normal → 0 · left-up → 1 (90°) · bottom-up → 2 (180°) · right-up → 3 (270°)
  // (needs one physical calibration pass, see omarchy-orient --watch)
  function orientationTransform(o) {
    if (o === "left-up") return "1"
    if (o === "right-up") return "3"
    if (o === "bottom-up") return "2"
    return "0"
  }

  function applyOrientation() {
    if (!persisted.autoOrient || !isTabletMode) return
    if (root.orientation === "unknown") return
    var t = orientationTransform(root.orientation)
    if (root.appliedFor !== root.orientation) {
      root.appliedFor = root.orientation
      rotateProcess.command = ["omarchy-rotate", "-s", t]
      rotateProcess.running = true
    }
  }

  function pollOrientation() {
    if (!orientationProbe.running) orientationProbe.running = true
  }

  // Phase 9 — folio keyboard USB presence.

  function pollKeyboard() {
    if (!kbProbe.running) kbProbe.running = true
  }

  function onKeyboardResult(attached) {
    root.kbAttached = attached
    var changed = !root.kbStateKnown || root.kbWasAttached !== attached
    root.kbWasAttached = attached
    root.kbStateKnown = true
    if (!changed || !persisted.autoSwitchMode) return
    // attached → laptop, detached → tablet (opt-in auto-switch, Phase 10)
    setMode(attached ? "laptop" : "tablet")
  }

  // ------------------------------------------------------------- plumbing

  Process { id: osdProcess }
  Process { id: rotateProcess }

  Process {
    id: orientationProbe
    command: ["busctl", "--system", "get-property",
              "net.hadess.SensorProxy", "/net/hadess/SensorProxy",
              "net.hadess.SensorProxy", "AccelerometerOrientation"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var m = /\[|'([a-z-]+)'|s "([a-z-]+)"/.exec(text)
        var o = m ? (m[1] || m[2] || "unknown") : "unknown"
        if (o === "undefined") o = "unknown"
        if (o !== root.orientation) {
          root.orientation = o
          root.applyOrientation()
        }
      }
    }
  }

  Process {
    id: kbProbe
    command: ["omarchy-kbdetect"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.onKeyboardResult(String(text).trim() === "attached")
      }
    }
  }

  Timer {
    id: poller
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (persisted.autoOrient) root.pollOrientation()
      root.pollKeyboard()   // Phase 9 presence tracking (auto-switch opt-in)
    }
  }

  function osd(icon, message) {
    if (osdProcess.running) return
    osdProcess.command = ["omarchy-osd", "-i", icon, "-m", message]
    osdProcess.running = true
  }

  // ---------------------------------------------------------------- IPC

  IpcHandler {
    target: "maxt.tablet-experience"

    function getState(): string {
      return JSON.stringify({
        mode: root.mode,
        tabletRotation: root.tabletRotation,
        autoOrient: root.autoOrient,
        autoSwitchMode: root.autoSwitchMode,
        kbAttached: root.kbAttached,
        orientation: root.orientation,
        isTabletMode: root.isTabletMode
      })
    }

    function getMode(): string {
      return root.mode
    }

    function toggle(): string {
      root.toggleMode()
      return root.mode
    }

    function setMode(value: string): string {
      root.setMode(String(value || "").toLowerCase())
      return root.mode
    }

    function setRotation(value: string): string {
      root.setRotationPreset(String(value || "").toLowerCase())
      return root.tabletRotation
    }

    function setAutoOrient(value: string): string {
      var on = String(value || "").toLowerCase()
      persisted.autoOrient = on === "on" || on === "true" || on === "1" || on === "yes"
      root.appliedFor = ""
      if (!persisted.autoOrient && isTabletMode) {
        // returning to manual control: leave the current transform alone
      }
      osd("rotate-cw", "Auto-orientation: " + (persisted.autoOrient ? "on (tablet only)" : "off"))
      return persisted.autoOrient ? "on" : "off"
    }

    function setAutoSwitch(value: string): string {
      var on = String(value || "").toLowerCase()
      persisted.autoSwitchMode = on === "on" || on === "true" || on === "1" || on === "yes"
      osd("keyboard", "Auto mode switch: " + (persisted.autoSwitchMode ? "on" : "off"))
      return persisted.autoSwitchMode ? "on" : "off"
    }
  }
}