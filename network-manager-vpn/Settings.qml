import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var pluginSettings: {
        return pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings ? pluginApi.pluginSettings : pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings ? pluginApi.manifest.metadata.defaultSettings : {
        };
    }

    // Local state
    property string editDisplayMode: root.pluginSettings.displayMode
    property string editConnectedColor: root.pluginSettings.connectedColor
    property string editDisconnectedColor: root.pluginSettings.disconnectedColor

    readonly property var tr: {
        return pluginApi && pluginApi.tr ? pluginApi.tr : (key) => {
            return key;
        };
    }

    property var displayModeModel: [{
        "key": "onhover",
        "name": I18n.tr("display-modes.on-hover")
    }, {
        "key": "alwaysShow",
        "name": I18n.tr("display-modes.always-show")
    }, {
        "key": "alwaysHide",
        "name": I18n.tr("display-modes.always-hide")
    }]

    // Save applies local state to settings
    function saveSettings() {
        pluginApi.pluginSettings.displayMode = root.editDisplayMode;
        pluginApi.pluginSettings.connectedColor = root.editConnectedColor;
        pluginApi.pluginSettings.disconnectedColor = root.editDisconnectedColor;
        pluginApi.saveSettings();

        Logger.i("NetworkManagerVpn", "Settings saved successfully");
    }

    NComboBox {
        label: I18n.tr("common.display-mode")
        description: I18n.tr("bar.volume.display-mode-description")
        minimumWidth: 200
        model: root.displayModeModel
        currentKey: root.editDisplayMode
        onSelected: (key) => {
            return root.editDisplayMode = key;
        }
    }

    NColorChoice {
        label: root.tr("settings.connectedColor") || "Connected color"
        description: root.tr("settings.connectedColorDescription") || "Chose the color to use for icon and text when connected"
        currentKey: root.editConnectedColor
        onSelected: (key) => {
            root.editConnectedColor = key;
        }
    }

    NColorChoice {
        label: root.tr("settings.disconnectedColor") || "Disconnected color"
        description: root.tr("settings.disconnectedColorDescription") || "Chose the color to use for icon and text when disconnected"
        currentKey: root.editDisconnectedColor
        onSelected: (key) => {
            root.editDisconnectedColor = key;
        }
    }

}
