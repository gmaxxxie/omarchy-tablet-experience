import QtQuick
import qs.Commons
import qs.Ui

// Tablet Experience — bar widget (Phase 8).
//
// Shows the current mode (Laptop/Tablet) as a bar button:
//   left click  toggle mode
//   right click cycle the enter-tablet rotation preset (off/180°/0°)
//
// The widget reads live state off the plugin's service singleton; the label
// updates on every mode change because `service.mode` is a notified property.
// Label is plain text (no nerd-glyph dependency) so it renders on any font.

BarWidget {
  id: root
  moduleName: "maxt.tablet-experience"

  readonly property var tabletService: bar ? bar.shell.serviceFor("maxt.tablet-experience") : null
  readonly property bool tablet: tabletService ? tabletService.isTabletMode : false

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  WidgetButton {
    id: button
    anchors.centerIn: parent
    bar: root.bar

    active: root.tablet
    useActiveColor: true
    text: root.tablet ? "Tablet" : "Laptop"
    tooltipText: root.tablet
      ? "Tablet mode — left click: laptop · right click: rotation preset (" + (root.tabletService ? root.tabletService.tabletRotation : "off") + ")"
      : "Laptop mode — left click: tablet · right click: rotation preset"

    onPressed: function(btn) {
      if (!root.tabletService) return
      if (btn === Qt.LeftButton) root.tabletService.toggleMode()
      else if (btn === Qt.RightButton) root.tabletService.cycleRotationPreset()
    }
  }
}