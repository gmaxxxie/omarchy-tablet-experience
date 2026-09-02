import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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
// (no OSD), manual switches show OSD feedback. Entering laptop mode always
// forces the display back to the default 0° landscape (silently), while the
// tablet rotation preset/autoOrient are kept for the next tablet entry.
//
// Tablet-mode top-bar toggle (v1.1): with no mouse there is no hover to
// reveal the (optionally hidden/transparent) Omarchy top bar, so in tablet
// mode a thin full-width edge strip above the bar toggles it: tap when the
// bar is hidden → show, tap again → hide. The strip is the plugin's own
// Top-layer surface (namespace maxt-tablet-bar-strip) and only exists in
// tablet mode; it drives the official `omarchy-toggle-bar` bar-off flag so
// the shell's own rendering/state stays authoritative.
//
// IPC (omarchy-shell maxt.tablet-experience <method>):
//   getState | getMode | toggle | setMode <laptop|tablet>
//   setRotation <off|0|2> | setAutoOrient <on|off> | setAutoSwitch <on|off>
//   rotateLeft | rotateRight        (90° relative steps, tablet mode)
//   toggleBar | setBarHidden <on|off|toggle>   (top-bar visibility)

Item {
  id: root

  Component.onCompleted: console.log("tablet-experience Service LOADED v3")

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
  // True while a relative (⟲/⟳) rotation is in flight, so its stdout result
  // updates the persisted preset instead of being ignored.
  property bool pendingRelative: false
  // Set when we entered laptop mode and still owe the display its reset to
  // the default 0° landscape — deferred until the rotation process is idle so
  // a rotation still in flight from tablet mode cannot swallow the reset.
  property bool pendingLaptopReset: false

  // Omarchy top-bar visibility (mirrors the `bar-off` flag that
  // omarchy-toggle-bar maintains). The strip shows/hides it in tablet mode.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")

  // Logical heights of the edge strip. Big when the bar is hidden (easy
  // reveal target), tiny when it is visible (so bar buttons stay reachable).
  readonly property real stripHiddenHeight: 16
  readonly property real stripShownHeight: 5

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

  // Manual 90° steps for the tablet popup (⟲/⟳). Rotate from the CURRENT
  // orientation and take control away from the sensor. "next" turns the
  // content counter-clockwise (= sensor left-up), "prev" clockwise
  // (= right-up); texp-rotate prints the new transform so the preset stays
  // in sync.
  function rotateStep(dir) {
    if (!isTabletMode) return
    if (rotateProcess.running) return
    persisted.autoOrient = false
    pendingRelative = true
    rotateProcess.command = ["texp-rotate", dir]
    rotateProcess.running = true
  }

  // Component methods used by the bar popup (⟲/⟳); the IpcHandler below
  // exposes the same actions over omarchy-shell for CLI/menu use.
  function rotateLeft() { rotateStep("next") }
  function rotateRight() { rotateStep("prev") }

  // Runs the deferred laptop-mode display reset once the rotation process
  // is idle. texp-rotate is idempotent, so re-applying transform 0 (and the
  // matching touch-device calibration) is harmless even if already at 0°.
  function tryLaptopReset() {
    if (!root.pendingLaptopReset || root.isTabletMode) return
    if (rotateProcess.running) return
    root.pendingLaptopReset = false
    rotateProcess.command = ["texp-rotate", "-s", "0"]
    rotateProcess.running = true
  }

  // Idempotent side-effect pass — only runs on real transitions.
  function applyNext() {
    osd("tablet", isTabletMode ? "Tablet mode" : "Laptop mode")
    if (!isTabletMode) {
      // Laptop: with the keyboard docked the panel is always used
      // face-up, so the display always returns to the default 0°
      // landscape. Silent (the mode OSD above already tells the user).
      // The tablet rotation preset/autoOrient are NOT touched — they
      // resume on the next tablet entry. Deferred until any rotation
      // still in flight finishes, so the reset is never silently dropped.
      root.pendingLaptopReset = true
      root.tryLaptopReset()
      return
    }
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

  Process {
    id: rotateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // NOTE: `persisted` must be addressed by id here (component scope), not
        // as root.persisted — ids are not properties of their declaring object.
        if (root.pendingRelative) {
          root.pendingRelative = false
          var m = /^([0-3])\s*$/.exec(String(text || "").trim())
          if (m) persisted.tabletRotation = m[1]
        }
        // A laptop-mode reset that had to wait for this process can start now.
        root.tryLaptopReset()
      }
    }
  }

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

  // ------------------------------------------------- tablet-mode bar toggle

  // Drive the OFFICIAL omarchy bar toggle (bar-off flag + syncHidden nudge)
  // so the shell's own rendering stays the single source of truth.
  function toggleTopBar() {
    barCmd.command = ["omarchy-toggle-bar", "toggle"]
    barCmd.running = true
  }

  function setTopBarHidden(on) {
    barCmd.command = ["omarchy-toggle-bar", on ? "on" : "off"]
    barCmd.running = true
  }

  Process { id: barCmd }

  // Mirror the bar-off flag (same probe Bar.qml uses). Watching the parent
  // directory catches flag creation AND removal.
  Process {
    id: barHiddenProbe
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function(line) { root.barHidden = String(line).trim() === "yes" }
    }
  }

  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: if (!barHiddenProbe.running) barHiddenProbe.running = true
  }

  // Edge strip: one Top-layer window per output, full width, parked at the
  // top edge. In tablet mode a tap toggles the top bar — the touch equivalent
  // of Omarchy's hover, and the requested "tap the top bar blank area to
  // show, tap again to hide". Never mapped in laptop mode (mouse hover works
  // there and the strip must not steal clicks).
  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: strip
        required property var modelData
        screen: modelData
        visible: root.isTabletMode
        color: "transparent"
        WlrLayershell.namespace: "maxt-tablet-bar-strip"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // `layerrule zindex … maxt-tablet-bar-strip` (installed with
        // config/hypr/tablet-experience.lua) keeps the strip above the bar so
        // the shown-state tap (hide the bar) reaches it.
        anchors { top: true; left: true; right: true }
        implicitWidth: 0
        implicitHeight: root.barHidden ? root.stripHiddenHeight : root.stripShownHeight

        Rectangle {
          anchors.fill: parent
          color: "transparent"

          // A subtle grab pill, only while the bar is hidden, so the tap zone
          // is discoverable without a mouse.
          Rectangle {
            width: 56
            height: 4
            radius: 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: (parent.height - height) / 2
            color: "#33ffffff"
            visible: root.barHidden && root.isTabletMode
          }

          TapHandler {
            enabled: root.isTabletMode
            onTapped: root.toggleTopBar()
          }
        }
      }
    }
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
        isTabletMode: root.isTabletMode,
        barHidden: root.barHidden
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

    function rotateLeft(): string {
      root.rotateStep("next")
      return root.tabletRotation
    }

    function rotateRight(): string {
      root.rotateStep("prev")
      return root.tabletRotation
    }

    function toggleBar(): string {
      root.toggleTopBar()
      return root.barHidden ? "hidden" : "shown"
    }

    function setBarHidden(value: string): string {
      var on = String(value || "toggle").toLowerCase()
      if (on === "on") root.setTopBarHidden(true)
      else if (on === "off") root.setTopBarHidden(false)
      else root.toggleTopBar()
      return root.barHidden ? "hidden" : "shown"
    }
  }
}