import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets
import "." as Local

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor
  readonly property string successIconKey: cfg.successIcon ?? defaults.successIcon ?? "network"
  readonly property string errorIconKey: cfg.errorIcon ?? defaults.errorIcon ?? "alert-circle"
  readonly property string loadingIconKey: cfg.loadingIcon ?? defaults.loadingIcon ?? "loader"
  readonly property int refreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 300

  // IP state - managed directly in widget like CustomButton
  property string currentIp: "n/a"
  property var ipData: null
  property string fetchState: "idle" // idle, loading, success, error
  property int lastFetchTime: 0

  readonly property string displayIp: currentIp
  readonly property bool isHot: fetchState === "success"

  // Bar position handling
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

  readonly property string currentIcon: {
    if (fetchState === "loading") return loadingIconKey;
    if (fetchState === "error") return errorIconKey;
    return successIconKey;
  }

  readonly property color iconColor: isHot ? Color.resolveColorKey(iconColorKey) : Color.mOnSurfaceVariant
  readonly property color textColor: isHot ? Color.mOnSurface : Color.mOnSurfaceVariant

  implicitWidth: pill.width
  implicitHeight: pill.height

  Component.onCompleted: {
    Logger.i("IpMonitor", "BarWidget loaded, fetching IP...");
    Qt.callLater(() => fetchIp());
  }

  // Watch for IPC refresh trigger from singleton service
  Connections {
    target: Local.IpMonitorService
    
    function onRefreshTriggerChanged() {
      Logger.i("IpMonitor", "BarWidget received refresh trigger from IPC, value:", Local.IpMonitorService.refreshTrigger);
      fetchIp();
    }
  }

  // curl process for fetching IP info (like CustomButton's textProc)
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
      Logger.i("IpMonitor", "BarWidget fetching IP info...");
    }

    onExited: function(exitCode, exitStatus) {
      var output = stdoutCollector.text;
      Logger.i("IpMonitor", "BarWidget process exited:", exitCode, "length:", output.length);

      if (exitCode === 0 && output.length > 0) {
        try {
          var data = JSON.parse(output);
          if (data.ip) {
            ipData = data;
            currentIp = data.ip;
            fetchState = "success";
            lastFetchTime = Date.now();
            Logger.i("IpMonitor", "BarWidget IP fetched:", currentIp);
          } else {
            throw new Error("No IP field in response");
          }
        } catch (e) {
          Logger.e("IpMonitor", "BarWidget parse error:", e.message);
          currentIp = "n/a";
          ipData = null;
          fetchState = "error";
        }
      } else {
        Logger.e("IpMonitor", "BarWidget curl failed:", exitCode);
        currentIp = "n/a";
        ipData = null;
        fetchState = "error";
      }
    }
  }

  // Auto-refresh timer
  Timer {
    id: autoRefreshTimer
    interval: refreshInterval * 1000
    running: interval > 0
    repeat: true
    onTriggered: fetchIp()
  }

  function fetchIp() {
    if (!ipFetchProcess.running) {
      ipFetchProcess.running = true;
    } else {
      Logger.i("IpMonitor", "BarWidget fetch already in progress");
    }
  }

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.currentIcon
    text: root.displayIp
    rotateText: isVerticalBar
    forceOpen: true
    autoHide: false
    customTextIconColor: root.iconColor

    tooltipText: {
      var lines = [];
      lines.push("Left click: Refresh IP and open panel");
      lines.push("Right click: Settings");
      if (root.fetchState === "success" && root.ipData) {
        var data = root.ipData;
        lines.push("");
        if (data.city || data.country) {
          var parts = [];
          if (data.city) parts.push(data.city);
          if (data.country) parts.push(data.country);
          lines.push(parts.join(", "));
        }
      }
      return lines.join("\n");
    }

    onClicked: {
      // Refresh IP on click
      fetchIp();
      // Also open panel
      if (pluginApi) {
        pluginApi.openPanel(root.screen, root);
      }
    }

    onRightClicked: {
      PanelService.showContextMenu(contextMenu, root, screen);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Copy IP",
        "action": "copy",
        "icon": "copy"
      },
      {
        "label": "Refresh IP",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      },
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "copy") {
        if (currentIp && currentIp !== "n/a") {
          Quickshell.execDetached(["sh", "-c", `printf '%s' '${currentIp}' | wl-copy`]);
          ToastService.showNotice("IP copied to clipboard: " + currentIp);
          Logger.i("IpMonitor", "Copied IP to clipboard:", currentIp);
        } else {
          ToastService.showNotice("No IP to copy");
        }
      } else if (action === "refresh") {
        fetchIp();
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }
}

