import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Rectangle {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)

  readonly property var mainInstance: pluginApi?.mainInstance

  implicitWidth: Style.capsuleHeight
  implicitHeight: Style.capsuleHeight

  readonly property bool barIsVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  color: Style.capsuleColor

  radius: Style.radiusL

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: Style.marginS
    layoutDirection: Qt.LeftToRight

    TailscaleIcon {
      pointSize: Style.fontSizeL
      applyUiScale: false
      crossed: !mainInstance?.tailscaleRunning
      color: {
        if (mainInstance?.tailscaleRunning) return Color.mPrimary
        return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      }
      opacity: mainInstance?.isRefreshing ? 0.5 : 1.0
    }


  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
      root.color = Color.mHover
    }

    onExited: {
      root.color = Style.capsuleColor
    }

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        if (mainInstance?.tailscaleInstalled) {
          mainInstance.toggleTailscale()
        }
      }
    }
  }
}
