import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Io

ColumnLayout {
    id: root

    property var pluginApi: null

    property string editPluggedInScript: pluginApi?.pluginSettings?.pluggedInScript || ""
    property string editOnBatteryScript: pluginApi?.pluginSettings?.onBatteryScript || ""

    spacing: Style.marginL

    NTextInput {
        Layout.fillWidth: true
        fontFamily: Settings.data.ui.fontFixed
        label: "Plugged In Script"
        description: "The script that will be executed when the battery is plugged in."
        placeholderText: "command1; command2; /path/to/script; ..."
        text: root.editPluggedInScript
        onTextChanged: root.editPluggedInScript = text
    }
    NTextInput {
        Layout.fillWidth: true
        fontFamily: Settings.data.ui.fontFixed
        label: "On Battery Script"
        description: "The script that will be executed when the battery is unplugged."
        placeholderText: "command1; command2; /path/to/script; ..."
        text: root.editOnBatteryScript
        onTextChanged: root.editOnBatteryScript = text
    }

    function saveSettings() {
        pluginApi.pluginSettings.pluggedInScript = root.editPluggedInScript;
        pluginApi.pluginSettings.onBatteryScript = root.editOnBatteryScript;
        pluginApi.saveSettings();
    }
}
