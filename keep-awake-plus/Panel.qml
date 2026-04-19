import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 320 * Style.uiScaleRatio
  property real contentPreferredHeight: 420 * Style.uiScaleRatio
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

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // --- Header ---
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerCol.implicitHeight + Style.marginM * 2

        ColumnLayout {
          id: headerCol
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          RowLayout {
            spacing: Style.marginS
            NIcon {
              icon: mainInstance?.active ? "coffee" : "coffee-off"
              color: (mainInstance?.active && mainInstance.scope === "full") ? Color.mPrimary : Color.mOnSurface
              pointSize: Style.fontSizeL
            }
            NText {
              Layout.fillWidth: true
              text: "Keep Awake"
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeL
              color: Color.mOnSurface
            }
          }
          NText {
            text: mainInstance?.active
                    ? mainInstance.scope + " · " + mainInstance.formatRemaining() + " remaining"
                    : "off"
            color: Qt.alpha(Color.mOnSurface, 0.7)
            pointSize: Style.fontSizeS
          }
        }
      }

      // --- Scope segmented control ---
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: scopeRow.implicitHeight + Style.marginM * 2

        RowLayout {
          id: scopeRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText { text: "Scope:"; color: Color.mOnSurface }

          Button {
            text: "Partial"
            Layout.fillWidth: true
            checkable: true
            checked: root.selectedScope === "partial"
            onClicked: root.selectedScope = "partial"
          }
          Button {
            text: "Full"
            Layout.fillWidth: true
            checkable: true
            checked: root.selectedScope === "full"
            onClicked: root.selectedScope = "full"
          }
        }
      }

      // --- Duration grid ---
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText { text: "Duration"; color: Color.mOnSurface }

          GridLayout {
            id: grid
            columns: 3
            rowSpacing: Style.marginS
            columnSpacing: Style.marginS
            Layout.fillWidth: true

            Repeater {
              model: {
                const base = mainInstance ? mainInstance.durations.slice() : [30, 60, 120, 240, 480];
                const labels = base.map(m => {
                  return { minutes: m, label: m < 60 ? (m + "m") : (m % 60 === 0 ? (m/60 + "h") : (Math.floor(m/60) + "h" + (m%60) + "m")) };
                });
                if (mainInstance?.includeUnlimited) labels.push({ minutes: -1, label: "∞" });
                return labels;
              }
              delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                highlighted: mainInstance?.active && (
                  (modelData.minutes === -1 && mainInstance.endEpoch === null) ||
                  (modelData.minutes !== -1 && mainInstance.durationLabel === modelData.label)
                )
                onClicked: {
                  const seconds = (modelData.minutes === -1) ? -1 : modelData.minutes * 60;
                  mainInstance.start(seconds, root.selectedScope);
                }
              }
            }
          }
        }
      }

      // --- Secondary actions ---
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Button {
          Layout.fillWidth: true
          text: "+" + (mainInstance?.quickExtendMinutes ?? 30) + "m extend"
          enabled: mainInstance?.active && mainInstance.endEpoch !== null
          onClicked: mainInstance.extend((mainInstance.quickExtendMinutes ?? 30) * 60)
        }
        Button {
          Layout.fillWidth: true
          text: "Disable"
          enabled: mainInstance?.active
          onClicked: mainInstance.off()
        }
      }
    }
  }
}
