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
        label: tr("settings.plugged_in_label", "When Plugged In")
        description: tr("settings.plugged_in_desc", "The script that will be executed when the system is plugged in.")
        placeholderText: "command1; command2; /path/to/script; ..."
        text: root.editPluggedInScript
        onTextChanged: root.editPluggedInScript = text
    }
    NTextInput {
        Layout.fillWidth: true
        fontFamily: Settings.data.ui.fontFixed
        label: tr("settings.on_battery_label", "When Oe Battery")
        description: tr("settings.on_battery_desc", "The script that will be executed when the system is on battery power.")
        placeholderText: "command1; command2; /path/to/script; ..."
        text: root.editOnBatteryScript
        onTextChanged: root.editOnBatteryScript = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NLabel {
            label: tr("settings.env_vars_title", "Additional Environment Variables Provided")
        }

        NLabel {
            description: `$BAT_PERCENTAGE: ${tr("settings.env_vars_percentage", "Battery Percentage")}`
        }
        NLabel {
            description: `$BAT_STATE: ${tr("settings.env_vars_state", "Battery State (Charging, Discharging, Fully Charged, etc.)")}`
        }
        NLabel {
            description: `$BAT_RATE: ${tr("settings.env_vars_rate", "Battery Charge rate (in Watts)")}`
        }
        NLabel {
            description: `$BAT_PATH: ${tr("settings.env_vars_path", "OS Battery path (/sys/class/power_supply/...)")}`
        }
    }

    function tr(key, fallback) {
        return pluginApi?.tr(key) || fallback;
    }

    function saveSettings() {
        pluginApi.pluginSettings.pluggedInScript = root.editPluggedInScript;
        pluginApi.pluginSettings.onBatteryScript = root.editOnBatteryScript;
        pluginApi.saveSettings();
    }
}
