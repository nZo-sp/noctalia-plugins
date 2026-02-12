import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 640 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  // IP data state - managed directly in panel
  property var ipData: null
  property string fetchState: "idle" // idle, loading, success, error

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("IpMonitor", "Panel initialized, fetching IP...");
    }
    // Fetch IP when panel opens
    Qt.callLater(() => fetchIp());
  }

  // curl process for fetching IP info
  Process {
    id: ipFetchProcess
    running: false
    command: ["curl", "-s", "-m", "10", "https://ipinfo.io"]
    stdout: StdioCollector {
      id: stdoutCollector
    }
    stderr: StdioCollector {
      id: stderrCollector
    }

    onStarted: {
      fetchState = "loading";
      Logger.i("IpMonitor", "Panel fetching IP info...");
    }

    onExited: function(exitCode, exitStatus) {
      var output = stdoutCollector.text;
      Logger.i("IpMonitor", "Panel process exited:", exitCode, "length:", output.length);

      if (exitCode === 0 && output.length > 0) {
        try {
          var data = JSON.parse(output);
          if (data.ip) {
            ipData = data;
            fetchState = "success";
            Logger.i("IpMonitor", "Panel IP fetched:", data.ip);
          } else {
            throw new Error("No IP field in response");
          }
        } catch (e) {
          Logger.e("IpMonitor", "Panel parse error:", e.message);
          ipData = null;
          fetchState = "error";
        }
      } else {
        Logger.e("IpMonitor", "Panel curl failed:", exitCode);
        ipData = null;
        fetchState = "error";
      }
    }
  }

  function fetchIp() {
    if (!ipFetchProcess.running) {
      ipFetchProcess.running = true;
    } else {
      Logger.i("IpMonitor", "Panel fetch already in progress");
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      // Header with refresh button
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: "IP Information"
          font.pointSize: Style.fontSizeL * Style.uiScaleRatio
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NButton {
          text: "Refresh"
          icon: "refresh"
          enabled: root.fetchState !== "loading"
          onClicked: {
            root.fetchIp();
          }
        }
      }

      // Main IP display
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: ipDisplayLayout.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          id: ipDisplayLayout
          anchors.centerIn: parent
          spacing: Style.marginM

          NIcon {
            icon: {
              if (root.fetchState === "loading") return "loader";
              if (root.fetchState === "error") return "alert-circle";
              return "network";
            }
            Layout.alignment: Qt.AlignHCenter
            pointSize: Style.fontSizeXXL * 2 * Style.uiScaleRatio
            color: {
              if (root.fetchState === "success") return Color.mPrimary;
              if (root.fetchState === "error") return Color.mError;
              return Color.mOnSurfaceVariant;
            }
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: {
              if (root.fetchState === "loading") return "Fetching IP...";
              if (root.fetchState === "error") return "Failed to fetch IP";
              if (root.ipData?.ip) return root.ipData.ip;
              return "n/a";
            }
            font.pointSize: Style.fontSizeXXL * Style.uiScaleRatio
            font.weight: Font.Bold
            font.family: Settings.data.ui.fontFixed
            color: Color.mOnSurface
          }

          NText {
            visible: root.fetchState === "success" && root.ipData
            Layout.alignment: Qt.AlignHCenter
            text: {
              var parts = [];
              if (root.ipData?.city) parts.push(root.ipData.city);
              if (root.ipData?.country) parts.push(root.ipData.country);
              return parts.join(", ");
            }
            font.pointSize: Style.fontSizeM * Style.uiScaleRatio
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // Details section
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM
        visible: root.fetchState === "success" && root.ipData

        NText {
          text: "Details"
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            Repeater {
              model: [
                { label: "IP Address", value: root.ipData?.ip ?? "n/a" },
                { label: "Hostname", value: root.ipData?.hostname ?? "n/a" },
                { label: "City", value: root.ipData?.city ?? "n/a" },
                { label: "Region", value: root.ipData?.region ?? "n/a" },
                { label: "Country", value: root.ipData?.country ?? "n/a" },
                { label: "Location", value: root.ipData?.loc ?? "n/a" },
                { label: "Postal Code", value: root.ipData?.postal ?? "n/a" },
                { label: "Timezone", value: root.ipData?.timezone ?? "n/a" },
                { label: "Organization", value: root.ipData?.org ?? "n/a" },
              ]

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                  text: modelData.label + ":"
                  font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                  color: Color.mOnSurfaceVariant
                  Layout.preferredWidth: 120
                }

                NText {
                  text: modelData.value
                  font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                  font.family: Settings.data.ui.fontFixed
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        // IPC Examples
        NText {
          text: "IPC Commands"
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
          Layout.topMargin: Style.marginM
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: examplesColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: examplesColumn
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            NText {
              text: "$ qs -c noctalia-shell ipc call plugin:ip-monitor refreshIp"
              font.pointSize: Style.fontSizeS * Style.uiScaleRatio
              font.family: Settings.data.ui.fontFixed
              color: Color.mPrimary
              Layout.fillWidth: true
              wrapMode: Text.WrapAnywhere
            }

            NText {
              text: "$ qs -c noctalia-shell ipc call plugin:ip-monitor toggle"
              font.pointSize: Style.fontSizeS * Style.uiScaleRatio
              font.family: Settings.data.ui.fontFixed
              color: Color.mPrimary
              Layout.fillWidth: true
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }
    }
  }
}

