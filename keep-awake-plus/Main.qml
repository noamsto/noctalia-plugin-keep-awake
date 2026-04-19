import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi: null

  // Live state mirrored from `system-awake status --json`
  property bool active: false
  property string scope: "partial"
  property string durationLabel: ""
  property real endEpoch: 0
  property int remainingSeconds: 0

  // Defaults from manifest metadata, overridable via pluginApi.pluginSettings
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string defaultScope: cfg.defaultScope ?? defaults.defaultScope ?? "partial"
  property var durations: cfg.durations ?? defaults.durations ?? [30, 60, 120, 240, 480]
  property bool includeUnlimited: cfg.includeUnlimited ?? defaults.includeUnlimited ?? true
  property bool showRemainingText: cfg.showRemainingText ?? defaults.showRemainingText ?? true
  property bool activateOnLeftClick: cfg.activateOnLeftClick ?? defaults.activateOnLeftClick ?? false
  property int quickExtendMinutes: cfg.quickExtendMinutes ?? defaults.quickExtendMinutes ?? 30
}
