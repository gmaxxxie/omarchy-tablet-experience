import QtQuick
import Quickshell
import Quickshell.Io

// Tablet Experience — Laptop/Tablet state machine (Phases 7–10).
//
// Persistent state (survives shell reloads via PersistentProperties):
//   mode             "laptop" | "tablet"
//   tabletRotation   rotation preset applied when ENTERING tablet mode:
//                    "off" | "0" (landscape) | "2" (180° fold)
//   autoOrient       opt-in: follow device posture while in tablet mode
//                    (normal→0°, left-up→90°, bottom-up→180°, right-up→270°,
//                    classified from the IIO accel via texp-orient — the
//                    iio-sensor-proxy D-Bus property stays "undefined" on
//                    this board); overrides the manual/preset rotation
//   autoSwitchMode   keyboard USB attach/detach (17ef:60fe) drives the mode
//                    automatically (attached→laptop, detached→tablet). ON by
//                    default; disable with IPC setAutoSwitch off
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
    // off(initial) | auto(sensor) | "0" | "1" | "2" | "3"
    property string tabletRotation: "off"
    property bool autoOrient: false
    // Folio keyboard attach/detach drives the mode: attached → laptop,
    // detached → tablet. Default ON — the X12 is a detachable.
    property bool autoSwitchMode: true
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
    // off (initial) -> auto (sensor) -> 0° -> 90° -> 180° -> 270° -> off
    var ring = ["off", "auto", "0", "1", "2", "3"]
    var idx = ring.indexOf(persisted.tabletRotation)
    setRotationPreset(ring[(idx + 1) % ring.length])
  }

  // The rotation a preset means: "off" = back to the initial orientation;
  // "auto" is handled by the sensor, no direct rotate.
  function rotationTarget(value) {
    return value === "off" ? "0" : value
  }

  function setRotationPreset(value) {
    if (["off", "auto", "0", "1", "2", "3"].indexOf(value) === -1) return
    persisted.tabletRotation = value
    // "auto" switches on sensor following; any fixed angle or off turns it
    // back off so the screen stays where the user put it.
    persisted.autoOrient = (value === "auto")
    osd("rotate-cw", "Rotation: " + rotationLabel(value))
    if (!isTabletMode) return
    if (persisted.autoOrient) {
      root.appliedFor = ""
      root.pollOrientation()   // read the sensor and apply right now
    } else if (!rotateProcess.running) {
      rotateProcess.command = ["texp-rotate", rotationTarget(value)]
      rotateProcess.running = true
    }
  }

  // Fixed mode keeps the CURRENT screen orientation as the preset (so
  // leaving auto does not snap back to 0°). Falls back to off/initial.
  function toFixedMode() {
    if (isTabletMode) {
      if (!monitorProbe.running) monitorProbe.running = true
    } else {
      setRotationPreset("off")
    }
  }

  function rotationLabel(value) {
    if (value === "auto") return "auto (sensor)"
    if (value === "0") return "landscape 0°"
    if (value === "1") return "portrait 90°"
    if (value === "2") return "flipped 180°"
    if (value === "3") return "portrait 270°"
    return "off (initial)"
  }

  // Idempotent side-effect pass — only runs on real transitions.
  function applyNext() {
    osd("tablet", isTabletMode ? "Tablet mode" : "Laptop mode")
    if (!isTabletMode) return
    // Entering tablet: default the rotation to sensor-following (auto)
    // unless an orientation was fixed explicitly.
    if (persisted.tabletRotation === "off") {
      setRotationPreset("auto")
      return
    }
    // Auto-orientation hands the display to the sensor; otherwise apply the
    // preset (off = back to initial 0°).
    if (!persisted.autoOrient && !rotateProcess.running) {
      rotateProcess.command = ["texp-rotate", rotationTarget(persisted.tabletRotation)]
      rotateProcess.running = true
    }
  }

  // Phase 6 — posture via texp-orient (sysfs accel, zero deps). Same
  // orientation convention as iio-sensor-proxy:
  //   normal → 0 · left-up → 1 (90°) · bottom-up → 2 (180°) · right-up → 3 (270°)
  // (needs one physical calibration pass, see texp-orient --watch)
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
      rotateProcess.command = ["texp-rotate", "-s", t]
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

  // Reads the current monitor transform so "Fixed" can freeze the screen
  // where it currently is instead of snapping back to 0°.
  Process {
    id: monitorProbe
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var ms = JSON.parse(text || "[]")
          if (Array.isArray(ms) && ms.length > 0)
            root.setRotationPreset(String(ms[0].transform || "0"))
        } catch (e) {}
      }
    }
  }

  Process {
    id: orientationProbe
    command: ["texp-orient", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var o = "unknown"
        try {
          var d = JSON.parse(text || "")
          if (d && typeof d.label === "string") o = d.label
        } catch (e) {}
        if (o !== root.orientation) {
          root.orientation = o
          root.applyOrientation()
        }
      }
    }
  }

  Process {
    id: kbProbe
    command: ["texp-kbdetect"]
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
      var enable = on === "on" || on === "true" || on === "1" || on === "yes"
      persisted.autoOrient = enable
      // Keep the rotation preset label consistent with the sensor state.
      if (enable && root.tabletRotation !== "auto") persisted.tabletRotation = "auto"
      else if (!enable && root.tabletRotation === "auto") persisted.tabletRotation = "off"
      root.appliedFor = ""
      osd("rotate-cw", "Auto-orientation: " + (enable ? "on (sensor)" : "off"))
      if (enable && isTabletMode) root.pollOrientation()
      return enable ? "on" : "off"
    }

    function setAutoSwitch(value: string): string {
      var on = String(value || "").toLowerCase()
      persisted.autoSwitchMode = on === "on" || on === "true" || on === "1" || on === "yes"
      osd("keyboard", "Auto mode switch: " + (persisted.autoSwitchMode ? "on" : "off"))
      return persisted.autoSwitchMode ? "on" : "off"
    }
  }
}