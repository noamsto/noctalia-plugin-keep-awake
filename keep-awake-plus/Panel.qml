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

  // Selected duration in minutes (-1 for unlimited). Mirrors active session
  // when one is running; otherwise a local "what to use on turn-on" state.
  property int selectedMinutes: _initialSelectedMinutes()

  // Selected scope. Same semantics as selectedMinutes.
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
    function onDurationLabelChanged() {
      if (mainInstance.active) root.selectedMinutes = root._minutesFromState();
    }
    function onScopeChanged() {
      if (mainInstance.active) root.selectedScope = mainInstance.scope;
    }
  }

  function _initialSelectedMinutes() {
    if (mainInstance?.active) return _minutesFromState();
    const list = mainInstance?.durations ?? [30, 60, 120, 240, 480];
    return list[0] ?? 30;
  }

  function _minutesFromState() {
    if (!mainInstance?.active) return root.selectedMinutes;
    if (mainInstance.endEpoch === null) return -1;  // unlimited
    // Match the active session to the nearest duration in the list.
    const list = mainInstance.durations ?? [];
    const label = mainInstance.durationLabel;
    for (const m of list) if (root._formatMinutes(m) === label) return m;
    return list[0] ?? 30;
  }

  function _formatMinutes(m) {
    if (m === -1) return "∞";
    if (m < 60) return m + "m";
    if (m % 60 === 0) return (m / 60) + "h";
    return Math.floor(m / 60) + "h" + (m % 60) + "m";
  }

  function _onDurationClicked(minutes) {
    root.selectedMinutes = minutes;
    if (mainInstance?.active) {
      // Silent reconfigure — no "enabled" toast on every click.
      const secs = (minutes === -1) ? -1 : minutes * 60;
      mainInstance.start(secs, root.selectedScope, true);
    }
  }

  function _onScopeToggled(keepDisplayAwake) {
    const newScope = keepDisplayAwake ? "full" : "partial";
    root.selectedScope = newScope;
    if (mainInstance?.active) {
      // Preserve remaining time; only the scope changes.
      const dur = (mainInstance.endEpoch === null) ? -1 : mainInstance.remainingSeconds;
      mainInstance.start(dur, newScope, true);
    }
  }

  function _onMainToggleClicked() {
    if (mainInstance?.active) {
      mainInstance.off(false);  // user-initiated → toast
    } else {
      const secs = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
      mainInstance.start(secs, root.selectedScope, false);  // user-initiated → toast
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

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
            const base = mainInstance ? mainInstance.durations.slice() : [30, 60, 120, 240, 480];
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
