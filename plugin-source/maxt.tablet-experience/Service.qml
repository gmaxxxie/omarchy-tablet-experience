import QtQuick
import Quickshell
import Quickshell.Io

// Tablet Experience — Laptop/Tablet state machine (Phase 7).
//
// Holds the current mode in PersistentProperties so it survives shell
// reloads, applies side effects idempotently (OSD feedback; optional rotation
// preset when entering tablet mode), and exposes itself over Charm IPC:
//
//   omarchy-shell maxt.tablet-experience toggle
//   omarchy-shell maxt.tablet-experience setMode tablet|laptop
//   omarchy-shell maxt.tablet-experience getState
//
// Rotation itself stays manual (omarchy-rotate, Phase 5) unless the user
// sets a tabletRotation preset (off|0|2; cycle via the bar widget's right
// click). Auto-orientation wiring (iio-sensor-proxy) hooks in later phases.

Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string mode: persisted.mode
  readonly property bool isTabletMode: persisted.mode === "tablet"
  readonly property string tabletRotation: persisted.tabletRotation

  PersistentProperties {
    id: persisted
    reloadableId: "maxt-tablet-experience"
    property string mode: "laptop"
    property string tabletRotation: "off"   // off | "0" (landscape) | "2" (180° fold)
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

  // Idempotent side-effect pass. Calling applyNext() again for the same mode
  // must not repeat visible feedback — it only runs on real transitions.
  function applyNext() {
    osd("tablet", isTabletMode ? "Tablet mode" : "Laptop mode")
    if (!isTabletMode) return
    if (persisted.tabletRotation !== "off") {
      rotateProcess.command = ["omarchy-rotate", persisted.tabletRotation]
      rotateProcess.running = true
    }
  }

  function osd(icon, message) {
    if (osdProcess.running) return
    osdProcess.command = ["omarchy-osd", "-i", icon, "-m", message]
    osdProcess.running = true
  }

  // ------------------------------------------------------------- plumbing

  Process { id: osdProcess }
  Process { id: rotateProcess }

  // ---------------------------------------------------------------- IPC

  IpcHandler {
    target: "maxt.tablet-experience"

    function getState(): string {
      return JSON.stringify({
        mode: root.mode,
        tabletRotation: root.tabletRotation,
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
  }
}