import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tablet Experience — bar widget (v1.8.0): always-mounted entry point with an
// input-method (fcitx5) quick switch, a virtual-keyboard toggle icon
// (show/hide squeekboard, live state highlight), a voice-input icon (v1.5,
// voxtype hold-to-talk overlay), a dedicated window-manage icon (v1.8,
// close / move-to-workspace popup) plus the ⋮ overflow popup.
// The IM switch, the keyboard icon and the voice-input icon are TABLET-MODE
// ONLY (in laptop mode the physical keyboard is docked); the mode button is
// always visible.
//
// The buttons are always mounted so there is always an entry point: laptop
// mode shows the mode label and the popup only offers Laptop/Tablet;
// tablet mode switches the label to 窗口 and unlocks, in order:
// Window (close / move-to-workspace) · Layout (dwindle/scrolling) · Rotation.
//
// In TABLET mode the simplified bar shows the two essential quick toggles
// (input method EN⇄中 + virtual keyboard) plus a ⋮ (overflow) button whose
// popup carries the mode switch, the tablet manage/rotation sections, and the
// "Extra bar icons" list of bar widgets the tablet declutter (Service.qml
// v1.2) parked there — tapping one mounts it back. LAPTOP mode keeps the
// default full bar and the plain mode button.
//
// The IM button (leftmost, tablet mode only) toggles fcitx5's active input
// method via `fcitx5-remote -t` — with the typical keyboard-us + rime pair
// that is exactly EN ⇄ 中 — and shows the current input method, so switching
// is one tap away (the bar's built-in keyboard-layout widget only cycles xkb
// layouts, not fcitx input methods).
//
// The keyboard icon toggles squeekboard through the same texp-vk path as
// SUPER+U / the bottom-edge swipe and polls squeekboard's D-Bus .Visible so
// the highlight always agrees with reality.
//
// Window targets are touch-first (Hyprland does not focus on touch tap):
// each action targets the window under the LAST TOUCH, recorded by the
// texp-touch daemon; single-finger taps also focus the tapped window
// now (also texp-touch), which scrolling-layout windows need.

Panel {
  id: root
  moduleName: "maxt.tablet-experience"
  ipcTarget: "maxt.tablet-window"

  property var service: bar ? bar.shell.serviceFor("maxt.tablet-experience") : null
  readonly property bool tablet: service ? service.isTabletMode : false
  readonly property var tabletRotation: service ? service.tabletRotation : "off"

  // Active workspace polling (id + tiled layout) for the move grid and the
  // layout buttons. Reloads 700ms after any layout/move action.
  property int wsId: 1
  property string wsLayout: "dwindle"
  property bool showMoveGrid: false
  // v1.8: dedicated window-manage popup (close / move), open state.
  property bool winOpened: false

  // Squeekboard visibility, read from its D-Bus .Visible property — the same
  // source texp-vk uses — so the icon agrees with SUPER+U and the swipe.
  property bool vkVisible: false

  // Current fcitx5 input method (fcitx5-remote -n), mapped to a short label.
  property string imName: ""
  readonly property string imLabel: imLabelFor(root.imName)

  function imLabelFor(name) {
    var n = String(name || "").toLowerCase()
    if (!n) return "IM"
    if (n.indexOf("rime") !== -1 || n.indexOf("wanxiang") !== -1 ||
        n.indexOf("chinese") !== -1 || n.indexOf("zh") === 0 ||
        n.indexOf("pinyin") !== -1 || n.indexOf("wubi") !== -1)
      return "中"
    if (n.indexOf("keyboard") !== -1 || n.indexOf("us") !== -1 ||
        n.indexOf("english") !== -1 || n.indexOf("en") === 0)
      return "EN"
    return n.length > 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase()
  }

  function toggleIm() {
    imCmd.command = ["fcitx5-remote", "-t"]
    imCmd.running = true
    imRefresh.interval = 350
    imRefresh.restart()
  }

  function toggleVk() {
    vkCmd.command = ["texp-vk", "toggle"]
    vkCmd.running = true
  }

  function runAction(args) {
    actProc.command = args
    actProc.running = true
    // Re-poll the workspace after the action lands.
    pollTimer.interval = 700
    pollTimer.restart()
  }

  Process { id: actProc }

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.spacing.xs

    // Input-method quick switch — TABLET MODE ONLY (laptop keeps the physical
    // keyboard and fcitx5's own trigger). Shows the active fcitx5 input method
    // (EN / 中 / other) and toggles it with one tap (fcitx5-remote -t).
    WidgetButton {
      id: imButton
      bar: root.bar
      visible: root.tablet
      text: root.imLabel
      active: root.imName !== "" && root.imName.indexOf("keyboard") === -1
      tooltipText: root.imName
        ? "Input method: " + root.imName + " (click to switch)"
        : "Input method (fcitx5 not running?)"
      onPressed: function() {
        root.toggleIm()
      }
    }

    // Virtual keyboard show/hide — TABLET MODE ONLY, one tap (same texp-vk
    // path as SUPER+U / the bottom-edge up-swipe; live state highlight).
    WidgetButton {
      id: vkButton
      bar: root.bar
      visible: root.tablet
      text: "\uF11C"            // fa-keyboard (glyph covered by the bar font, verified)
      active: root.vkVisible
      tooltipText: root.vkVisible
        ? "Hide virtual keyboard (Super+U)"
        : "Show virtual keyboard (Super+U)"
      onPressed: function() {
        root.toggleVk()
        // repaint the state quickly after a toggle, then fall back to the slow poll
        vkRefreshTimer.interval = 350
        vkRefreshTimer.restart()
      }
    }

    // Voice input (voxtype) — TABLET MODE ONLY (v1.5): opens/closes the
    // bottom hold-to-talk button. Press & hold there to dictate, release to
    // transcribe and type at the cursor (voxtype record start/stop).
    WidgetButton {
      id: voiceButton
      bar: root.bar
      visible: root.tablet
      text: "\uF130"            // fa-microphone (glyph covered by the bar font, verified)
      active: root.service ? root.service.voiceInputOpen : false
      tooltipText: root.service && root.service.voiceInputOpen
        ? "Hide voice input button"
        : "Voice input — hold to talk (voxtype)"
      onPressed: function() {
        if (root.service) root.service.toggleVoiceInput()
      }
    }

    // Window manage — TABLET MODE ONLY (v1.8): a dedicated icon so close /
    // move-to-workspace are one tap away, no longer buried in ⋮.
    WidgetButton {
      id: windowButton
      bar: root.bar
      visible: root.tablet
      text: "\uF2D2"            // fa-window-restore (glyph covered by the bar font, verified)
      active: root.winOpened
      tooltipText: "Window manage — close / move to workspace (tablet)"
      onPressed: function() {
        if (root.opened) root.close()
        root.winOpened = !root.winOpened
      }
    }

    // Tablet overflow ⋮ — v1.2 simplified bar: hosts window manage, rotation
    // and the hidden bar icons behind the essentials (IM + VK toggles above).
    WidgetButton {
      id: moreButton
      bar: root.bar
      visible: root.tablet
      text: "\uF142"           // fa-ellipsis-v („more“; glyph verified)
      active: root.opened
      tooltipText: "More — rotation & hidden bar icons (tablet)"
      onPressed: function() {
        root.winOpened = false
        root.toggle()
      }
    }


    WidgetButton {
      id: button
      bar: root.bar
      visible: !root.tablet
      text: "\uF109"   // fa-laptop (verified present)
      active: root.opened || root.tablet
      tooltipText: "Laptop mode — open for Tablet mode"

      onPressed: function(btn) {
        if (btn === Qt.RightButton && root.service) root.service.cycleRotationPreset()
        else root.toggle()
      }
    }
  }

  PopupCard {
    id: panel
    anchorItem: root.tablet ? moreButton : button
    owner: root
    bar: root.bar
    open: root.opened
    triggerMode: "click"
    contentWidth: panel.fittedContentWidth(Style.space(240))
    contentHeight: panel.fittedContentHeight(actionList.implicitHeight)

    Column {
      id: actionList
      anchors.fill: parent
      anchors.margins: Style.spacing.popupPadding
      spacing: Style.spacing.sm

      // ---- mode switch: always available
      PanelSectionHeader {
        text: "Tablet"
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          width: (parent.width - parent.spacing) / 2
          height: Style.space(40)
          text: "Laptop"
          active: !root.tablet
          onClicked: { if (root.service) root.service.setMode("laptop") }
        }
        Button {
          width: (parent.width - parent.spacing) / 2
          height: Style.space(40)
          text: "Tablet"
          active: root.tablet
          onClicked: { if (root.service) root.service.setMode("tablet") }
        }
      }

      // ---- layout / rotation: unlocked in tablet mode only (window
      // close / move now live in their own popup, v1.8)
      Column {
        visible: root.tablet
        width: parent.width
        spacing: Style.spacing.sm

        PanelSeparator { }

        PanelSectionHeader {
          text: "Layout · Workspace " + root.wsId + (root.wsLayout === "scrolling" ? " · Scrolling" : "")
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(40)
            text: "Dwindle"
            active: root.wsLayout === "dwindle"
            onClicked: { root.runAction(["texp-window", "layout", "dwindle"]) }
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(40)
            text: "Scrolling"
            active: root.wsLayout === "scrolling"
            onClicked: { root.runAction(["texp-window", "layout", "scrolling"]) }
          }
        }

        PanelSeparator { }

        PanelSectionHeader {
          text: "Rotation" + (root.tabletRotation === "auto"
            ? "" : " · " + {"off": "off", "0": "0°", "1": "90°", "2": "180°", "3": "270°"}[root.tabletRotation])
        }

        // Auto (sensor) + manual 90° steps, icon-only — replaces the old
        // numeric angle picker. ⟲/⟳ rotate from the CURRENT orientation and
        // take control away from the sensor; the preset follows the applied
        // transform, shown in the section header above.
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Button {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(40)
            text: "\uF14E"        // fa-compass — sensor-following "Auto"
            active: root.tabletRotation === "auto"
            tooltipText: "Auto-rotate: sensor-following (on/off)"
            onClicked: { if (root.service) root.service.setRotationPreset("auto") }
          }
          Button {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(40)
            text: "\uF2EA"        // fa-rotate-left → content 90° counter-clockwise
            tooltipText: "Rotate left (90° counter-clockwise)"
            onClicked: { if (root.service) root.service.rotateLeft() }
          }
          Button {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(40)
            text: "\uF2F9"        // fa-rotate-right → content 90° clockwise (NOT fa-rotate U+F2F1 — that one renders as the generic refresh circle)
            tooltipText: "Rotate right (90° clockwise)"
            onClicked: { if (root.service) root.service.rotateRight() }
          }
        }
      }

      // ---- tablet overflow: bar icons hidden by the v1.2 declutter live
      // here; tapping one brings it back to the bar at its old position.
      Column {
        visible: root.tablet && root.service && root.service.overflowItems.length > 0
        width: parent.width
        spacing: Style.spacing.sm

        PanelSeparator { }

        PanelSectionHeader {
          text: "Extra bar icons"
        }

        Repeater {
          model: root.service ? root.service.overflowItems : []
          delegate: Button {
            width: parent.width
            height: Style.space(36)
            iconText: modelData.mounted ? "\u2713" : " "
            text: modelData.label
            active: modelData.mounted
            tooltipText: modelData.mounted ? "On the bar — tap to hide" : "Hidden — tap to show"
            onClicked: {
              if (!root.service) return
              if (modelData.mounted) root.service.hideBarWidget(modelData.id)
              else root.service.bringBackBarWidget(modelData.id)
              root.close()
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(36)
            text: "Hide all"
            tooltipText: "Hide every non-essential bar icon"
            onClicked: {
              if (root.service) root.service.hideAllBarIcons()
              root.close()
            }
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(36)
            text: "Show all"
            tooltipText: "Show every bar icon (still in tablet mode)"
            onClicked: {
              if (root.service) root.service.showAllBarIcons()
              root.close()
            }
          }
        }
      }

      // Small bottom breathing room so the card does not hug the last row.
      Item {
        width: parent.width
        height: Style.space(24)
      }
    }
  }

  // Window-manage popup (v1.8): close / move-to-workspace in tablet mode,
  // one tap away from the dedicated window icon. Targets the window under
  // the last touch (texp-touch records it; texp-window resolves it).
  PopupCard {
    id: winPanel
    anchorItem: windowButton
    owner: root
    bar: root.bar
    open: root.winOpened
    triggerMode: "click"
    contentWidth: winPanel.fittedContentWidth(Style.space(240))
    contentHeight: winPanel.fittedContentHeight(winList.implicitHeight)

    Column {
      id: winList
      anchors.fill: parent
      anchors.margins: Style.spacing.popupPadding
      spacing: Style.spacing.sm

      PanelSectionHeader {
        text: "Window"
      }

      Button {
        height: Style.space(40)
        iconText: "✕"
        text: "Close"
        onClicked: { root.runAction(["texp-window", "close"]); root.winOpened = false }
      }

      Button {
        height: Style.space(40)
        iconText: "➜"
        text: "Move to Workspace"
        onClicked: { root.showMoveGrid = !root.showMoveGrid }
      }

      // 2x5 grid of workspace targets; the current workspace is highlighted.
      Grid {
        id: winGrid
        visible: root.showMoveGrid
        width: parent.width
        columns: 5
        rowSpacing: Style.spacing.sm
        columnSpacing: Style.spacing.sm

        Repeater {
          model: 10
          delegate: Button {
            width: (winGrid.width - winGrid.columnSpacing * (winGrid.columns - 1)) / winGrid.columns
            height: Style.space(32)
            text: String(index + 1)
            active: root.wsId === index + 1
            onClicked: {
              root.runAction(["texp-window", "move", String(index + 1)])
              root.winOpened = false
            }
          }
        }
      }
    }
  }

  // The plugin service QML re-instantiates after every shell.json mutation
  // (plugin reload); keep our reference pointing at the CURRENT instance so
  // the popup's toggle state and actions never hit a stale one.
  Timer {
    id: serviceTimer
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var current = bar ? bar.shell.serviceFor("maxt.tablet-experience") : null
      if (current !== root.service) root.service = current
    }
  }

  // -------- active-workspace poll (id + tiled layout)
  Process {
    id: wsProbe
    running: true
    command: ["hyprctl", "activeworkspace", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.id !== undefined && d.tiledLayout !== undefined) {
            root.wsId = d.id
            root.wsLayout = String(d.tiledLayout || "dwindle")
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 1500
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!wsProbe.running) wsProbe.running = true
    }
  }

  // -------- input method (fcitx5): toggle process + name poll
  Process {
    id: imCmd
  }

  Process {
    id: imProbe
    command: ["fcitx5-remote", "-n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = String(text || "").trim()
        if (n !== root.imName) root.imName = n
      }
    }
  }

  Timer {
    id: imRefresh
    interval: 1500
    running: root.tablet         // icon hidden in laptop mode — nothing to poll
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!imProbe.running) imProbe.running = true
    }
  }

  // -------- virtual keyboard: toggle process + D-Bus visibility poll
  Process {
    id: vkCmd
  }

  Process {
    id: vkProbe
    command: ["busctl", "--user", "get-property",
              "sm.puri.OSK0", "/sm/puri/OSK0", "sm.puri.OSK0", "Visible"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.vkVisible = /true/.test(text || "")
    }
  }

  Timer {
    id: vkRefreshTimer
    interval: 1500
    running: root.tablet        // icon hidden in laptop mode — nothing to poll
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!vkProbe.running) vkProbe.running = true
    }
  }

  Component.onCompleted: console.log("MAXT-WIDGET-ONLINE v1.8 mode=" + (root.tablet ? "tablet" : "laptop"))
}
