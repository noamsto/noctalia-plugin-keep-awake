import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 360 * Style.uiScaleRatio
  property real contentPreferredHeight: 480 * Style.uiScaleRatio
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool allowAttach: true

  // Local selected scope. Mirrors live scope while active; falls back to default otherwise.
  property string selectedScope: mainInstance?.active
                                   ? mainInstance.scope
                                   : (mainInstance?.defaultScope ?? "partial")

  Connections {
    target: mainInstance
    function onActiveChanged() {
      if (mainInstance.active) root.selectedScope = mainInstance.scope;
    }
  }

  function formatDuration(minutes) {
    if (minutes === -1) return "∞";
    if (minutes < 60) return minutes + "m";
    if (minutes % 60 === 0) return (minutes / 60) + "h";
    return Math.floor(minutes / 60) + "h" + (minutes % 60) + "m";
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // ─────────────────── Header ───────────────────
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerCol.implicitHeight + Style.marginM * 2

        ColumnLayout {
          id: headerCol
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: mainInstance?.active ? "coffee" : "coffee-off"
              pointSize: Style.fontSizeL
              color: mainInstance?.active
                ? (mainInstance.scope === "full" ? Color.mPrimary : Color.mSecondary)
                : Color.mOnSurfaceVariant
            }

            NText {
              Layout.fillWidth: true
              text: "Keep Awake"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            // Status pill
            Rectangle {
              visible: mainInstance?.active ?? false
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: statusText.implicitWidth + Style.marginM * 2
              implicitHeight: statusText.implicitHeight + Style.marginXS * 2
              radius: height / 2
              color: Qt.alpha(
                mainInstance?.scope === "full" ? Color.mPrimary : Color.mSecondary,
                0.15
              )

              NText {
                id: statusText
                anchors.centerIn: parent
                text: (mainInstance?.scope || "") + " · " + (mainInstance?.formatRemaining() || "")
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightMedium
                color: mainInstance?.scope === "full" ? Color.mPrimary : Color.mSecondary
              }
            }
          }

          NText {
            Layout.fillWidth: true
            visible: !(mainInstance?.active ?? false)
            text: "Off"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // ─────── Active-session banner (visible only when active) ───────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: activeRow.implicitHeight + Style.marginM * 2
        visible: mainInstance?.active ?? false
        color: Qt.alpha(Color.mPrimary, 0.08)
        radius: Style.radiusM
        border.width: 1
        border.color: Qt.alpha(Color.mPrimary, 0.25)

        RowLayout {
          id: activeRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "clock"
            pointSize: Style.fontSizeM
            color: Color.mPrimary
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            NText {
              text: (mainInstance?.formatRemaining() || "") + " remaining"
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightSemiBold
              color: Color.mOnSurface
            }

            NText {
              text: "Thermal guard: " + (mainInstance?.thermalGuardActive ? "active" : "off")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }
      }

      // ─────────────────── Scope ───────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          NIcon { icon: "settings"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
          NText {
            text: "Scope"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurfaceVariant
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NButton {
            Layout.fillWidth: true
            text: "Partial"
            icon: "moon"
            tooltipText: "Suspend + lid inhibit · monitor may sleep"
            outlined: root.selectedScope !== "partial"
            backgroundColor: Color.mSecondary
            textColor: Color.mOnSecondary
            onClicked: root.selectedScope = "partial"
          }
          NButton {
            Layout.fillWidth: true
            text: "Full"
            icon: "sun"
            tooltipText: "Block everything — monitor stays on"
            outlined: root.selectedScope !== "full"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            onClicked: root.selectedScope = "full"
          }
        }
      }

      // ─────────────────── Duration ───────────────────
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          NIcon { icon: "hourglass"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
          NText {
            text: "Duration"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurfaceVariant
          }
        }

        GridLayout {
          columns: 3
          rowSpacing: Style.marginS
          columnSpacing: Style.marginS
          Layout.fillWidth: true

          Repeater {
            model: {
              const base = mainInstance ? mainInstance.durations.slice() : [30, 60, 120, 240, 480];
              const labels = base.map(m => ({ minutes: m, label: root.formatDuration(m) }));
              if (mainInstance?.includeUnlimited) labels.push({ minutes: -1, label: "∞" });
              return labels;
            }
            delegate: NButton {
              Layout.fillWidth: true
              text: modelData.label
              readonly property bool isActive: mainInstance?.active && (
                (modelData.minutes === -1 && mainInstance.endEpoch === null) ||
                (modelData.minutes !== -1 && mainInstance.durationLabel === modelData.label)
              )
              outlined: !isActive
              backgroundColor: root.selectedScope === "full" ? Color.mPrimary : Color.mSecondary
              textColor: root.selectedScope === "full" ? Color.mOnPrimary : Color.mOnSecondary
              onClicked: {
                const seconds = (modelData.minutes === -1) ? -1 : modelData.minutes * 60;
                mainInstance.start(seconds, root.selectedScope);
              }
            }
          }
        }
      }

      // ─────────────────── Bottom actions ───────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          Layout.fillWidth: true
          text: "+" + (mainInstance?.quickExtendMinutes ?? 30) + "m"
          icon: "clock-plus"
          outlined: true
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          enabled: (mainInstance?.active ?? false) && mainInstance.endEpoch !== null
          onClicked: mainInstance.extend((mainInstance.quickExtendMinutes ?? 30) * 60)
        }

        NButton {
          Layout.fillWidth: true
          text: "Disable"
          icon: "player-stop"
          backgroundColor: Color.mError
          textColor: Color.mOnError
          enabled: mainInstance?.active ?? false
          onClicked: mainInstance.off()
        }
      }
    }
  }
}
