import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string defaultScope: cfg.defaultScope ?? defaults.defaultScope ?? "partial"
  property bool showRemainingText: cfg.showRemainingText ?? defaults.showRemainingText ?? true
  property bool activateOnLeftClick: cfg.activateOnLeftClick ?? defaults.activateOnLeftClick ?? false
  property int quickExtendMinutes: cfg.quickExtendMinutes ?? defaults.quickExtendMinutes ?? 30
  property bool includeUnlimited: cfg.includeUnlimited ?? defaults.includeUnlimited ?? true
  property string durationsCsv: (cfg.durations ?? defaults.durations ?? []).join(", ")

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    // Default scope
    RowLayout {
      Layout.fillWidth: true
      NText { text: "Default scope"; Layout.fillWidth: true; color: Color.mOnSurface }
      ComboBox {
        model: ["partial", "full"]
        currentIndex: root.defaultScope === "full" ? 1 : 0
        onActivated: root.defaultScope = model[currentIndex]
      }
    }

    NToggle {
      label: "Show remaining time beside icon"
      checked: root.showRemainingText
      onToggled: checked => root.showRemainingText = checked
    }

    NToggle {
      label: "Left click re-activates last combo (right click opens panel)"
      checked: root.activateOnLeftClick
      onToggled: checked => root.activateOnLeftClick = checked
    }

    RowLayout {
      Layout.fillWidth: true
      NText { text: "Quick-extend (minutes)"; Layout.fillWidth: true; color: Color.mOnSurface }
      SpinBox {
        from: 5; to: 240; stepSize: 5
        value: root.quickExtendMinutes
        onValueModified: root.quickExtendMinutes = value
      }
    }

    RowLayout {
      Layout.fillWidth: true
      NText { text: "Duration choices (min, comma-separated)"; Layout.fillWidth: true; color: Color.mOnSurface }
      TextField {
        Layout.preferredWidth: 200
        text: root.durationsCsv
        onEditingFinished: root.durationsCsv = text
      }
    }

    NToggle {
      label: "Show ∞ (unlimited) option"
      checked: root.includeUnlimited
      onToggled: checked => root.includeUnlimited = checked
    }
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
    if (arr.length > 0) {
      pluginApi.pluginSettings.durations = arr;
    }

    pluginApi.saveSettings();
    Logger.i("keep-awake-plus", "Settings saved");
  }
}
