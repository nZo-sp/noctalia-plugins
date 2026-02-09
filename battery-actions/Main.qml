import QtQuick
import Quickshell.Io
import qs.Commons
import Quickshell.Services.UPower

Item {
    id: root
    property var pluginApi: null
    property var battery: UPower.onBattery

    Component.onCompleted: {
        Logger.i("BatteryActions", `Battery Actions loaded w/ api: ${pluginApi}`);
    }

    onBatteryChanged: {
        if (battery && pluginApi?.pluginSettings) {
            Logger.i("BatteryActions", "On battery!");
            executor.command = ["sh", "-c", pluginApi.pluginSettings.onBatteryScript];
        } else {
            Logger.i("BatteryActions", "Plugged in!");
            executor.command = ["sh", "-c", pluginApi.pluginSettings.pluggedInScript];
        }
        executor.running = true;
        executor.command = [];
    }

    Process {
        id: executor
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) {
                    Logger.e("BatteryThreshold", `Execution failed: ${text}`);
                }
            }
        }
    }
}
