import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 320 * Style.uiScaleRatio
  property real contentPreferredHeight: 420 * Style.uiScaleRatio
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool allowAttach: true

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    NText {
      anchors.centerIn: parent
      text: "Keep Awake+ (panel stub)"
      color: Color.mOnSurface
    }
  }
}
