import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance

  implicitWidth: row.implicitWidth + Style.marginS * 2
  implicitHeight: Style.baseWidgetSize

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Style.marginXS

    NIcon {
      icon: "coffee-outline"
      color: Color.mOnSurface
      pointSize: Style.fontSizeM
    }
  }
}
