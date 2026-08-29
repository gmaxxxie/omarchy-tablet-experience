import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tablet Experience — bar widget (Phase 8, v0.3: window-manage popup).
//
// One bar button that opens a small popup with touch-sized actions:
//   ✕ 关闭窗口   — omarchy-window close   (window under last touch / focused)
//   ─ 最小化     — omarchy-window minimize (move to scratchpad special ws)
//   ⛶ 最大化     — omarchy-window maximize (toggle)
//   ⟲ 还原默认   — omarchy-window default  (un-max + un-fullscreen + un-float)
//   Laptop/Tablet mode toggle + rotation preset cycle (kept from v0.2)
//
// Tablet mode: the label becomes 窗口 (window manage); the actions target the
// window the user last touched, tracked by the omarchy-touch daemon —
// Hyprland does not focus windows on touch tap, so "focused" is wrong there.

Panel {
  id: root
  moduleName: "maxt.tablet-experience"
  ipcTarget: "maxt.tablet-window"

  readonly property var service: bar ? bar.shell.serviceFor("maxt.tablet-experience") : null
  readonly property bool tablet: service ? service.isTabletMode : false
  readonly property var tabletRotation: service ? service.tabletRotation : "off"

  function rotationLabel() {
    if (root.tabletRotation === "0") return "landscape 0°"
    if (root.tabletRotation === "2") return "flipped 180°"
    return "off"
  }

  function runAction(action) {
    actProc.command = ["omarchy-window", action]
    actProc.running = true
  }

  Process { id: actProc }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.centerIn: parent
    bar: root.bar
    text: root.tablet ? "窗口" : "Laptop"
    tooltipText: root.tablet
      ? "Window manage (close / minimize / maximize / restore) + Tablet mode"
      : "Window manage + Laptop/Tablet mode"

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
    contentWidth: panel.fittedContentWidth(Style.space(230))
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
        onClicked: { root.runAction("close"); root.close() }
      }
      Button {
        height: Style.space(40)
        iconText: "─"
        text: "最小化"
        onClicked: { root.runAction("minimize"); root.close() }
      }
      Button {
        height: Style.space(40)
        iconText: "⛶"
        text: "最大化"
        onClicked: { root.runAction("maximize"); root.close() }
      }
      Button {
        height: Style.space(40)
        iconText: "⟲"
        text: "还原默认"
        onClicked: { root.runAction("default"); root.close() }
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
        text: "旋转预设: " + root.rotationLabel()
        onClicked: { if (root.service) root.service.cycleRotationPreset() }
      }
    }
  }
}