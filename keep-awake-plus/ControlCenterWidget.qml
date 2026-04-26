import QtQuick
import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property bool active: main?.active ?? false
  readonly property string scope: main?.scope ?? ""
  readonly property string remainingText: main ? main.formatRemaining() : ""

  function buildTooltip() {
    if (!active) return "Keep Awake · off";
    const tg = (main && main.thermalGuardActive) ? "active" : "off";
    return "Keep Awake · " + scope + " · " + remainingText + " left · thermal guard: " + tg;
  }

  icon:        active ? "coffee" : "coffee-off"
  hot:         active
  tooltipText: buildTooltip()

  // Match Option B click semantics: left opens the full panel (scope picker,
  // duration menu, thermal guard), right toggles inhibit off.
  onClicked:      pluginApi?.openPanel(screen, this)
  onRightClicked: { if (main) main.off(); }
}
