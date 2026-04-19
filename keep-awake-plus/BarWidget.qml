import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"

  readonly property var mainInstance: pluginApi?.mainInstance

  readonly property bool active: mainInstance ? mainInstance.active : false
  readonly property string scope: mainInstance ? mainInstance.scope : ""
  readonly property string remainingText: mainInstance ? mainInstance.formatRemaining() : ""
  readonly property bool showText: mainInstance ? mainInstance.showRemainingText : true
  readonly property bool activateOnLeftClick: mainInstance ? mainInstance.activateOnLeftClick : false

  readonly property real contentWidth: isVertical ? Style.capsuleHeight
    : Math.round(layout.implicitWidth + Style.marginM * 2)
  readonly property real contentHeight: isVertical ? Math.round(layout.implicitHeight + Style.marginM * 2)
    : Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight
  Layout.alignment: Qt.AlignVCenter

  function buildTooltip() {
    if (!root.active) return "Keep Awake · off";
    const tg = (mainInstance && mainInstance.thermalGuardActive) ? "active" : "off";
    return "Keep Awake · " + root.scope + " · " + root.remainingText + " left · thermal guard: " + tg;
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: layout
      anchors.centerIn: parent
      spacing: Style.marginXS

      NIcon {
        icon: root.active ? "coffee" : "coffee-outline"
        color: (root.active && root.scope === "full") ? Color.mPrimary : Color.mOnSurface
        pointSize: Style.fontSizeM
      }

      NText {
        visible: root.active && root.showText && root.remainingText.length > 0
        text: root.remainingText
        color: Color.mOnSurface
        pointSize: Style.fontSizeS
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (mainInstance) mainInstance.off();
      } else if (mouse.button === Qt.MiddleButton) {
        if (mainInstance) mainInstance.toggleLast();
      } else if (mouse.button === Qt.LeftButton) {
        if (root.activateOnLeftClick) {
          if (mainInstance) mainInstance.toggleLast();
        } else {
          if (pluginApi) pluginApi.openPanel(root.screen, root);
        }
      }
    }

    onEntered: {
      const t = buildTooltip();
      if (t) TooltipService.show(root, t, BarService.getTooltipDirection());
    }
    onExited: TooltipService.hide()
  }
}
