import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  readonly property int minutesToMillis: 10_000
  property var pluginApi: null

  property int updateInterval: pluginApi?.pluginSettings?.updateInterval || pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval
  property string updateTerminalCommand: pluginApi?.pluginSettings?.updateTerminalCommand || pluginApi?.manifest?.metadata.defaultSettings?.updateTerminalCommand
  property string currentIconName: pluginApi?.pluginSettings?.currentIconName || pluginApi?.manifest?.metadata?.defaultSettings?.currentIconName
  property bool hideOnZero: pluginApi?.pluginSettings?.hideOnZero || pluginApi?.manifest?.metadata?.defaultSettings?.hideOnZero


  property string customCmdGetNumUpdate: pluginApi?.pluginSettings.customCmdGetNumUpdate || ""
  property string customCmdDoSystemUpdate: pluginApi?.pluginSettings.customCmdDoSystemUpdate || ""

  implicitWidth: root.implicitWidth

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.i("UpdateCount", "Settings UI loaded");
  }

  NToggle {
    id: widgetSwitch
    label: pluginApi?.tr("settings.hideWidget.label")
    description: pluginApi?.tr("settings.hideWidget.desc")
    checked: root.hideOnZero
    onToggled: function (checked) {
      root.hideOnZero = checked;
    }
  }

  RowLayout {
    spacing: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.currentIconName.label")
    }

    NText {
      text: root.currentIconName
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NIcon {
      icon: root.currentIconName
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NButton {
      text: pluginApi?.tr("settings.changeIcon.label")
      onClicked: {
        Logger.i("UpdateCount", "Icon selector button clicked.");
        changeIcon.open();
      }
    }

    NIconPicker {
      id: changeIcon
      onIconSelected: function (icon) {
        root.currentIconName = icon;
      }
    }
  }

  NDivider {
    visible: true
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.terminal.label")
    description: pluginApi?.tr("settings.terminal.desc")
    placeholderText: pluginApi?.tr("settings.terminal.placeholder")
    text: root.updateTerminalCommand
    onTextChanged: root.updateTerminalCommand = text
  }

  NTextInput {
    // Layout.fillWidth: true
    label: pluginApi?.tr("settings.customCmdGetNumUpdate.label")
    description: pluginApi?.tr("settings.customCmdGetNumUpdate.desc")
    placeholderText: pluginApi?.tr("settings.customCmdGetNumUpdate.placeholder")
    text: root.customCmdGetNumUpdate
    onTextChanged: root.customCmdGetNumUpdate = text
  }

  NTextInput {
    // Layout.fillWidth: true
    label: pluginApi?.tr("settings.customCmdDoSystemUpdate.label")
    description: pluginApi?.tr("settings.customCmdDoSystemUpdate.desc")
    placeholderText: pluginApi?.tr("settings.customCmdDoSystemUpdate.placeholder")
    text: root.customCmdDoSystemUpdate
    onTextChanged: root.customCmdDoSystemUpdate = text
  }

  NDivider {
    visible: true
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.updateInterval.label")
      description: pluginApi?.tr("settings.updateInterval.desc")
    }

    NSlider {
      from: 5
      to: 180
      value: root.updateInterval / root.minutesToMillis
      stepSize: 5
      onValueChanged: {
        root.updateInterval = value * root.minutesToMillis;
      }
    }

    NText {
      text: (root.updateInterval / root.minutesToMillis).toString().padStart(3, " ") + " minutes"
      color: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mOnPrimary
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("UpdateCount", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.updateInterval = root.updateInterval;
    pluginApi.pluginSettings.updateTerminalCommand = root.updateTerminalCommand;
    pluginApi.pluginSettings.currentIconName = root.currentIconName;
    pluginApi.pluginSettings.hideOnZero = root.hideOnZero;

    pluginApi.pluginSettings.customCmdGetNumUpdate = root.customCmdGetNumUpdate;
    pluginApi.pluginSettings.customCmdDoSystemUpdate = root.customCmdDoSystemUpdate;

    pluginApi.saveSettings();
    pluginApi?.mainInstance?.startGetNumUpdates();

    Logger.i("UpdateCount", "Settings saved successfully");
    pluginApi.closePanel(root.screen);
  }
}
