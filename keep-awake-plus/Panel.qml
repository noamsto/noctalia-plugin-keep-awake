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
  property real contentPreferredHeight: contentCol.implicitHeight + Style.marginM * 2
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool allowAttach: true

  // Selection state. While a session is active, the panel snapshots the
  // session's values on open/(re)activation; clicking a button locally
  // mutates these and either silently reconfigures (if active) or serves
  // as the start arg (if off).
  property int selectedMinutes: _initialSelectedMinutes()
  property string selectedScope: mainInstance?.active
    ? mainInstance.scope
    : (mainInstance?.defaultScope ?? "partial")

  Connections {
    target: mainInstance
    function onActiveChanged() {
      if (mainInstance.active) {
        root.selectedScope = mainInstance.scope;
        root.selectedMinutes = root._minutesFromState();
      }
    }
  }

  function _initialSelectedMinutes() {
    if (mainInstance?.active) return _minutesFromState();
    return mainInstance?.durations?.[0] ?? 30;
  }

  function _minutesFromState() {
    if (mainInstance.endEpoch === null) return -1;  // unlimited
    const list = mainInstance.durations ?? [];
    const label = mainInstance.durationLabel;
    for (const m of list) if (root._formatMinutes(m) === label) return m;
    return list[0] ?? 30;
  }

  // Mirrors the shell's format_label — keep in sync for label matching.
  function _formatMinutes(m) {
    if (m === -1) return "∞";
    if (m < 60) return m + "m";
    if (m % 60 === 0) return (m / 60) + "h";
    const mm = m % 60;
    return Math.floor(m / 60) + "h" + (mm < 10 ? "0" + mm : mm) + "m";
  }

  function _onDurationClicked(minutes) {
    root.selectedMinutes = minutes;
    if (mainInstance?.active) {
      const secs = (minutes === -1) ? -1 : minutes * 60;
      mainInstance.start(secs, root.selectedScope, true);
    }
  }

  function _onScopeToggled(keepDisplayAwake) {
    const newScope = keepDisplayAwake ? "full" : "partial";
    root.selectedScope = newScope;
    if (!mainInstance?.active) return;
    // Preserve remaining time; fall back to the selected duration if the
    // poll's remainingSeconds is 0 (`timeout 0s` would mean unlimited).
    let dur;
    if (mainInstance.endEpoch === null) {
      dur = -1;
    } else if (mainInstance.remainingSeconds >= 1) {
      dur = mainInstance.remainingSeconds;
    } else {
      dur = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
    }
    mainInstance.start(dur, newScope, true);
  }

  function _onMainToggleClicked() {
    if (mainInstance?.active) {
      mainInstance.off(false);
    } else {
      const secs = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
      mainInstance.start(secs, root.selectedScope, false);
    }
  }

  Item {
    id: panelContainer
    anchors.fill: parent

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      // ───────────── Header ─────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: mainInstance?.active ? "coffee" : "coffee-off"
          pointSize: Style.fontSizeXL
          color: mainInstance?.active
            ? (mainInstance.scope === "full" ? Color.mPrimary : Color.mSecondary)
            : Color.mOnSurfaceVariant
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: "Keep Awake"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }
          NText {
            text: mainInstance?.active
              ? (mainInstance.formatRemaining() + " remaining"
                  + (mainInstance.scope === "full" ? " · display on" : " · display may sleep"))
              : "Off"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      // ───────────── Duration grid ─────────────
      GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        columns: 3
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginXS

        Repeater {
          model: {
            const base = (mainInstance?.durations ?? []).slice();
            const arr = base.map(m => ({ minutes: m, label: root._formatMinutes(m) }));
            if (mainInstance?.includeUnlimited) arr.push({ minutes: -1, label: "∞" });
            return arr;
          }
          delegate: NButton {
            Layout.fillWidth: true
            text: modelData.label
            fontSize: Style.fontSizeM
            readonly property bool isSelected: modelData.minutes === root.selectedMinutes
            outlined: !isSelected
            backgroundColor: root.selectedScope === "full" ? Color.mPrimary : Color.mSecondary
            textColor: root.selectedScope === "full" ? Color.mOnPrimary : Color.mOnSecondary
            onClicked: root._onDurationClicked(modelData.minutes)
          }
        }
      }

      // ───────────── Keep-display-awake toggle ─────────────
      NToggle {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        label: "Keep display awake"
        description: "When off, monitor may dim/sleep while system stays awake"
        icon: root.selectedScope === "full" ? "sun" : "moon"
        checked: root.selectedScope === "full"
        onToggled: checked => root._onScopeToggled(checked)
      }

      // ───────────── Bottom action row ─────────────
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        spacing: Style.marginS

        NButton {
          Layout.fillWidth: true
          visible: (mainInstance?.active ?? false) && mainInstance.endEpoch !== null
          text: "+" + (mainInstance?.quickExtendMinutes ?? 30) + "m"
          icon: "clock-plus"
          outlined: true
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: mainInstance.extend((mainInstance.quickExtendMinutes ?? 30) * 60)
        }

        NButton {
          Layout.fillWidth: true
          text: (mainInstance?.active ?? false) ? "Turn off" : "Turn on"
          icon: "power"
          backgroundColor: (mainInstance?.active ?? false) ? Color.mError : Color.mPrimary
          textColor: (mainInstance?.active ?? false) ? Color.mOnError : Color.mOnPrimary
          onClicked: root._onMainToggleClicked()
        }
      }
    }
  }
}
