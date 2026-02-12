import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueIconColor: cfg.iconColor ?? defaults.iconColor
  property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 300
  property string valueSuccessIcon: cfg.successIcon ?? defaults.successIcon ?? "hierarchy-2"
  property string valueErrorIcon: cfg.errorIcon ?? defaults.errorIcon ?? "alert-circle"
  property string valueLoadingIcon: cfg.loadingIcon ?? defaults.loadingIcon ?? "loader"

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.d("IpMonitor", "Settings UI loaded");
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    // Appearance section
    NText {
      text: "Appearance"
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NComboBox {
      label: "Icon Color"
      description: "Color for the icon when IP is successfully fetched"
      model: Color.colorKeyModel
      currentKey: root.valueIconColor
      onSelected: key => root.valueIconColor = key
    }

    // State Icons section
    NText {
      text: "State Icons"
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
      Layout.topMargin: Style.marginM
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Success Icon"
      description: "Icon name to show when IP is successfully fetched"
      placeholderText: "hierarchy-2"
      text: root.valueSuccessIcon
      onTextChanged: root.valueSuccessIcon = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Error Icon"
      description: "Icon name to show when IP fetch fails"
      placeholderText: "alert-circle"
      text: root.valueErrorIcon
      onTextChanged: root.valueErrorIcon = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Loading Icon"
      description: "Icon name to show while fetching IP"
      placeholderText: "loader"
      text: root.valueLoadingIcon
      onTextChanged: root.valueLoadingIcon = text
    }

    // Behavior section
    NText {
      text: "Behavior"
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
      Layout.topMargin: Style.marginM
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Auto-refresh Interval (seconds)"
      description: "How often to automatically refresh IP info. Set to 0 to disable auto-refresh."
      placeholderText: "300"
      text: root.valueRefreshInterval.toString()
      onTextChanged: {
        var val = parseInt(text);
        if (!isNaN(val) && val >= 0 && val <= 86400) {
          root.valueRefreshInterval = val;
        }
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("IpMonitor", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.iconColor = root.valueIconColor;
    pluginApi.pluginSettings.refreshInterval = root.valueRefreshInterval;
    pluginApi.pluginSettings.successIcon = root.valueSuccessIcon;
    pluginApi.pluginSettings.errorIcon = root.valueErrorIcon;
    pluginApi.pluginSettings.loadingIcon = root.valueLoadingIcon;
    pluginApi.saveSettings();

    Logger.d("IpMonitor", "Settings saved successfully");
  }
}
