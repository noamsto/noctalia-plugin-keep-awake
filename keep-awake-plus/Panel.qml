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
  readonly property bool active: mainInstance ? mainInstance.active : false

  // Selection state. While a session is active, the panel snapshots the
  // session's values on open/(re)activation; clicking a button locally
  // mutates these and either silently reconfigures (if active) or serves
  // as the start arg (if off).
  property int selectedMinutes: _initialSelectedMinutes()
  property string selectedScope: root.active
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
    if (root.active) return _minutesFromState();
    return mainInstance?.durations?.[0] ?? 30;
  }

  function _minutesFromState() {
    if (mainInstance.endEpoch === null) return -1;  // unlimited
    const list = mainInstance.durations ?? [];
    const label = mainInstance.durationLabel;
    for (const m of list) if (mainInstance.formatLabel(m * 60) === label) return m;
    return list[0] ?? 30;
  }

  function _onDurationClicked(minutes) {
    root.selectedMinutes = minutes;
    if (root.active) {
      const secs = (minutes === -1) ? -1 : minutes * 60;
      mainInstance.start(secs, root.selectedScope);
    }
  }

  function _onScopeToggled(keepDisplayAwake) {
    const newScope = keepDisplayAwake ? "full" : "partial";
    root.selectedScope = newScope;
    if (!root.active) return;
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
    mainInstance.start(dur, newScope);
  }

  function _onMainToggleClicked() {
    if (root.active) {
      mainInstance.off();
    } else {
      const secs = (root.selectedMinutes === -1) ? -1 : root.selectedMinutes * 60;
      mainInstance.start(secs, root.selectedScope);
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
          icon: root.active ? "coffee" : "coffee-off"
          pointSize: Style.fontSizeXL
          color: root.active
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
            text: root.active
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
            const arr = base.map(m => ({ minutes: m, label: mainInstance.formatLabel(m * 60) }));
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
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        spacing: Style.marginS

        Item {
          readonly property real iconSlot: Style.fontSizeXL * 1.4
          Layout.preferredWidth: iconSlot
          Layout.preferredHeight: iconSlot
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            anchors.centerIn: parent
            icon: "sun"
            pointSize: Style.fontSizeXL
            color: Color.mPrimary
            opacity: root.selectedScope === "full" ? 1.0 : 0.0
            rotation: root.selectedScope === "full" ? 0 : -90
            scale: root.selectedScope === "full" ? 1.0 : 0.6
            Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
          }
          NIcon {
            anchors.centerIn: parent
            icon: "moon"
            pointSize: Style.fontSizeXL
            color: Color.mSecondary
            opacity: root.selectedScope === "full" ? 0.0 : 1.0
            rotation: root.selectedScope === "full" ? 90 : 0
            scale: root.selectedScope === "full" ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
          }
        }

        NToggle {
          Layout.fillWidth: true
          label: "Keep display awake"
          description: "When off, monitor may dim/sleep while system stays awake"
          checked: root.selectedScope === "full"
          onToggled: checked => root._onScopeToggled(checked)
        }
      }

      // ───────────── Bottom action row ─────────────
      RowLayout {
        id: actionRow
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        spacing: Style.marginS

        // Animated slot for the extend button — width grows/collapses instead
        // of popping. Keeps the main button's visible center stable.
        Item {
          id: extendSlot
          readonly property bool shown: root.active && mainInstance.endEpoch !== null
          readonly property real slotWidth: Math.max(0, (actionRow.width - actionRow.spacing) / 2)
          Layout.preferredWidth: shown ? slotWidth : 0
          Layout.preferredHeight: extendBtn.implicitHeight
          Layout.alignment: Qt.AlignVCenter
          clip: true

          Behavior on Layout.preferredWidth {
            NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
          }

          NButton {
            id: extendBtn
            width: extendSlot.slotWidth
            height: extendSlot.height
            text: "+" + (mainInstance?.quickExtendMinutes ?? 30) + "m"
            icon: "clock-plus"
            outlined: true
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            opacity: extendSlot.shown ? 1.0 : 0.0
            enabled: opacity > 0.5
            onClicked: mainInstance.extend((mainInstance.quickExtendMinutes ?? 30) * 60)

            Behavior on opacity {
              NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
            }
          }
        }

        // Single button: colors morph in place via NButton's Behavior on
        // color. Crossfading two stacked NButtons fights NButton's internal
        // enabled→opacity step and produces a visible kick at the 50% mark.
        // When inactive, the tint mirrors the bar pill so the user can
        // preview which scope the button is about to activate.
        NButton {
          Layout.fillWidth: true
          text: root.active ? "Turn off" : "Turn on"
          icon: "power"
          backgroundColor: root.active
            ? Color.mError
            : (root.selectedScope === "full" ? Color.mPrimary : Color.mSecondary)
          textColor: root.active
            ? Color.mOnError
            : (root.selectedScope === "full" ? Color.mOnPrimary : Color.mOnSecondary)
          onClicked: root._onMainToggleClicked()
        }
      }
    }
  }
}
