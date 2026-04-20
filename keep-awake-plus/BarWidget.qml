import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool active: mainInstance ? mainInstance.active : false
  readonly property string scope: mainInstance ? mainInstance.scope : ""
  readonly property string remainingText: mainInstance ? mainInstance.formatRemaining() : ""
  readonly property bool showText: mainInstance ? mainInstance.showRemainingText : true
  readonly property bool activateOnLeftClick: mainInstance ? mainInstance.activateOnLeftClick : false

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  function buildTooltip() {
    if (!root.active) return "Keep Awake · off";
    const tg = (mainInstance && mainInstance.thermalGuardActive) ? "active" : "off";
    return "Keep Awake · " + root.scope + " · " + root.remainingText + " left · thermal guard: " + tg;
  }

  BarPill {
    id: pill
    screen: root.screen
    icon: root.active ? "coffee" : "coffee-off"
    text: (root.active && root.showText) ? root.remainingText : ""
    tooltipText: root.buildTooltip()
    customIconColor: root.active
      ? (root.scope === "full" ? Color.mPrimary : Color.mSecondary)
      : Color.mOnSurface
    oppositeDirection: BarService.getPillDirection(root)
    onClicked: {
      if (root.activateOnLeftClick) {
        if (mainInstance) mainInstance.toggleLast();
      } else if (pluginApi) {
        pluginApi.openPanel(root.screen, root);
      }
    }
    onRightClicked: { if (mainInstance) mainInstance.off(); }
    onMiddleClicked: { if (mainInstance) mainInstance.toggleLast(); }
  }
}
