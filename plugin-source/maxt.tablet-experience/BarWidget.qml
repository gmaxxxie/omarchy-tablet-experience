import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tablet Experience — bar widget (v0.4): tablet-only window-manage popup.
//
// The bar button and all window-management entries ONLY appear while the
// machine is in Tablet mode (laptop mode keeps the bar clean; the mode can
// still be switched from inside the popup, SUPER+SHIFT+U, or the menu).
//
// Popup actions (touch-first; target = window under the last touch, because
// Hyprland does not focus windows on touch tap):
//   ✕ 关闭窗口            omarchy-window close
//   ➜ 移动到工作区 N      omarchy-window move N        (grid 1..10)
//   Dwindle / Scrolling   omarchy-window layout <mode> (active workspace,
//                         persisted like omarchy's own SUPER+L toggle)
//   Laptop / Tablet       mode switch (same as before)
//   旋转预设               rotation preset cycle

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

  // --------- the button + popup are tablet-mode only
  visible: root.tablet

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.centerIn: parent
    bar: root.bar
    text: "窗口"
    active: root.opened
    useActiveColor: true
    tooltipText: "Window manage: close / move workspace / layout"

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

      PanelSectionHeader {
        text: "窗口 — Window"
      }

      Button {
        height: Style.space(40)
        iconText: "✕"
        text: "关闭窗口"
        onClicked: { root.runAction(["omarchy-window", "close"]); root.close() }
      }

      Button {
        height: Style.space(40)
        iconText: "➜"
        text: "移动到工作区"
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
        text: "布局 · 工作区 " + root.wsId + (root.wsLayout === "scrolling" ? " (scrolling)" : "")
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
          onClicked: { if (root.service) { root.service.setMode("laptop") } }
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
        text: "旋转预设: " + root.rotationLabel()
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
    running: root.visible && root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!wsProbe.running) wsProbe.running = true
    }
  }
}