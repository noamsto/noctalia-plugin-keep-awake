import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  function _get(key, fallback) { return cfg[key] ?? defaults[key] ?? fallback; }

  property string defaultScope: _get("defaultScope", "partial")
  property bool showRemainingText: _get("showRemainingText", true)
  property bool activateOnLeftClick: _get("activateOnLeftClick", false)
  property int quickExtendMinutes: _get("quickExtendMinutes", 30)
  property bool includeUnlimited: _get("includeUnlimited", true)
  property string durationsCsv: (_get("durations", [])).join(", ")

  spacing: Style.marginL

  NComboBox {
    Layout.fillWidth: true
    label: "Default scope"
    description: "partial = system awake, monitor may sleep; full = everything blocked"
    model: [
      { key: "partial", name: "partial" },
      { key: "full", name: "full" }
    ]
    currentKey: root.defaultScope
    onSelected: key => root.defaultScope = key
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show remaining time beside icon"
    checked: root.showRemainingText
    onToggled: checked => root.showRemainingText = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: "Left click re-activates last combo"
    description: "Right click opens panel instead"
    checked: root.activateOnLeftClick
    onToggled: checked => root.activateOnLeftClick = checked
  }

  NSpinBox {
    Layout.fillWidth: true
    label: "Quick-extend (minutes)"
    from: 5; to: 240; stepSize: 5
    value: root.quickExtendMinutes
    onValueChanged: root.quickExtendMinutes = value
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Duration choices (minutes, comma-separated)"
    text: root.durationsCsv
    onEditingFinished: root.durationsCsv = text
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show ∞ (unlimited) option"
    checked: root.includeUnlimited
    onToggled: checked => root.includeUnlimited = checked
  }

  // Called by Noctalia's settings framework when the dialog closes.
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("keep-awake-plus", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.defaultScope = root.defaultScope;
    pluginApi.pluginSettings.showRemainingText = root.showRemainingText;
    pluginApi.pluginSettings.activateOnLeftClick = root.activateOnLeftClick;
    pluginApi.pluginSettings.quickExtendMinutes = root.quickExtendMinutes;
    pluginApi.pluginSettings.includeUnlimited = root.includeUnlimited;

    const arr = root.durationsCsv
      .split(/\s*,\s*/)
      .map(s => parseInt(s, 10))
      .filter(n => !isNaN(n) && n > 0);
    if (arr.length > 0) pluginApi.pluginSettings.durations = arr;

    pluginApi.saveSettings();
    Logger.i("keep-awake-plus", "Settings saved");
  }
}
