import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tablet Experience — bar widget (v0.5): always-mounted window-manage popup.
//
// The button is always visible so there is always an entry point: laptop
// mode shows the mode label and the popup only offers Laptop/Tablet +
// rotation; tablet mode switches the label to 窗口 and unlocks the
// window-manage section (close / move-to-workspace / layout switch).
//
// Window targets are touch-first (Hyprland does not focus on touch tap):
// each action targets the window under the LAST TOUCH, recorded by the
// omarchy-touch daemon; single-finger taps also focus the tapped window
// now (also omarchy-touch), which scrolling-layout windows need.

Panel {
  id: root
  moduleName: "maxt.tablet-experience"
  ipcTarget: "maxt.tablet-window"

  readonly property var service: bar ? bar.shell.serviceFor("maxt.tablet-experience") : null
  readonly property bool tablet: service ? service.isTabletMode : false
  readonly property var tabletRotation: service ? service.tabletRotation : "off"

  // Active workspace polling (id + tiled layout) for the move grid and the
  // layout buttons. Reloads 700ms after any layout/move action.
  property int wsId: 1
  property string wsLayout: "dwindle"
  property bool showMoveGrid: false

  function rotationLabel() {
    if (root.tabletRotation === "0") return "landscape 0°"
    if (root.tabletRotation === "2") return "flipped 180°"
    return "off"
  }

  function runAction(args) {
    actProc.command = args
    actProc.running = true
    // Re-poll the workspace after the action lands.
    pollTimer.interval = 700
    pollTimer.restart()
  }

  Process { id: actProc }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.centerIn: parent
    bar: root.bar
    text: root.tablet ? "\uF108" : "\uF109"   // fa-tablet / fa-laptop (verified in JetBrainsMono Nerd Font)
    active: root.opened || root.tablet
    tooltipText: root.tablet
      ? "Window manage: close / move workspace / layout"
      : "Laptop mode — open for Tablet mode"

    onPressed: function(btn) {
      if (btn === Qt.RightButton && root.service) root.service.cycleRotationPreset()
      else root.toggle()
    }
  }

  PopupCard {
    id: panel
    anchorItem: button
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

      // ---------- window manage section: tablet mode only
      Column {
        visible: root.tablet
        width: parent.width
        spacing: Style.spacing.sm

        PanelSectionHeader {
          text: "Window"
        }

        Button {
          height: Style.space(40)
          iconText: "✕"
          text: "Close"
          onClicked: { root.runAction(["omarchy-window", "close"]); root.close() }
        }

        Button {
          height: Style.space(40)
          iconText: "➜"
          text: "Move to Workspace"
          onClicked: { root.showMoveGrid = !root.showMoveGrid }
        }

        // 2x5 grid of workspace targets; the current workspace is highlighted.
        Grid {
          id: wsGrid
          visible: root.showMoveGrid
          width: parent.width
          columns: 5
          rowSpacing: Style.spacing.sm
          columnSpacing: Style.spacing.sm

          Repeater {
            model: 10
            delegate: Button {
              width: (wsGrid.width - wsGrid.columnSpacing * (wsGrid.columns - 1)) / wsGrid.columns
              height: Style.space(32)
              text: String(index + 1)
              active: root.wsId === index + 1
              onClicked: {
                root.runAction(["omarchy-window", "move", String(index + 1)])
                root.close()
              }
            }
          }
        }

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
            onClicked: { root.runAction(["omarchy-window", "layout", "dwindle"]) }
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(40)
            text: "Scrolling"
            active: root.wsLayout === "scrolling"
            onClicked: { root.runAction(["omarchy-window", "layout", "scrolling"]) }
          }
        }
      }

      PanelSeparator { }

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

      Button {
        width: parent.width
        height: Style.space(40)
        iconText: "⟳"
        text: "Rotation: " + root.rotationLabel()
        onClicked: { if (root.service) root.service.cycleRotationPreset() }
      }
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

  Component.onCompleted: console.log("MAXT-WIDGET-ONLINE v0.5 mode=" + (root.tablet ? "tablet" : "laptop"))
}
