import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "." as Local

Item {
  id: root
  property var pluginApi: null

  Component.onCompleted: {
    Logger.i("IpMonitor", "Main.qml initialized");
  }

  // IPC handlers
  IpcHandler {
    target: "plugin:ip-monitor"
    
    function refreshIp() {
      Logger.i("IpMonitor", "IPC refreshIp called - triggering widget refresh");
      Local.IpMonitorService.triggerRefresh();
      ToastService.showNotice("Refreshing IP info...");
    }
    
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.openPanel(screen);
        });
      }
    }
  }
}

