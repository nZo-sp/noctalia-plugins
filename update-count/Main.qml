import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property int updateCount: 0

  readonly property int updateInterval: pluginApi?.pluginSettings.updateInterval || pluginApi?.manifest?.metadata.defaultSettings?.updateInterval || 0
  readonly property string configuredTerminal: pluginApi?.pluginSettings.updateTerminalCommand || pluginApi?.manifest?.metadata.defaultSettings?.configuredTerminal || ""

  readonly property string customCmdGetNumUpdate: pluginApi?.pluginSettings.customCmdGetNumUpdate || ""
  readonly property string customCmdDoSystemUpdate: pluginApi?.pluginSettings.customCmdDoSystemUpdate || ""

  //
  // ------ Configuration ------
  //
  property bool hasCommandYay: false
  property bool hasCommandParu: false
  property bool hasCommandCheckupdates: false
  property bool hasCommandDnf: false

  property var updater: [
    {
      key: "hasCommandYay",
      name: "yay",
      cmdCheck: "command -v yay >/dev/null 2>&1",
      cmdGetNumUpdates: "yay -Sy >/dev/null 2>&1; yay -Quq 2>/dev/null | wc -l",
      cmdDoSystemUpdate: "yay -Syu"
    },
    {
      key: "hasCommandParu",
      name: "paru",
      cmdCheck: "command -v paru >/dev/null 2>&1",
      cmdGetNumUpdates: "paru -Sy >/dev/null 2>&1; paru -Quq 2>/dev/null | wc -l",
      cmdDoSystemUpdate: "paru -Syu"
    },
    {
      key: "hasCommandCheckupdates",
      name: "checkupdates",
      cmdCheck: "command -v pacman >/dev/null 2>&1",
      cmdGetNumUpdates: "checkupdates 2>/dev/null | wc -l",
      cmdDoSystemUpdate: "sudo pacman -Syu"
    },
    {
      key: "hasCommandDnf",
      name: "dnf",
      cmdCheck: "command -v dnf >/dev/null 2>&1",
      cmdGetNumUpdates: "dnf -q check-update --refresh 2>/dev/null | awk 'BEGIN{c=0} /^[[:alnum:]][^[:space:]]*[[:space:]]/ {c++} END{print c+0}'",
      cmdDoSystemUpdate: "sudo dnf upgrade -y --refresh"
    }
  ]

  //
  // ------ Initialization -----
  //
  Process {
    id: checkAvailableCommands

    command: ["sh", "-c", root.buildCommandCheckScript()]

    stdout: StdioCollector {
      onStreamFinished: {
        root.checkForUpdater(text);
        getNumUpdates.running = true;
      }
    }
  }

  function buildCommandCheckScript() {
    return updater.map(e => `${e.cmdCheck} && echo ${e.key}=1 || echo ${e.key}=0`).join("; ");
  }

  function checkForUpdater(text) {
    const tokens = text.trim().split(/\s+/);

    for (let i = 0; i < tokens.length; i++) {
      const parts = tokens[i].split("=");
      if (parts.length !== 2)
        continue;

      const key = parts[0];
      const present = (parts[1] === "1");
      root[key] = present;

      const entry = updater.find(e => e.key === key);
      const label = entry ? entry.name : key;

      if (present)
        Logger.i("UpdateCount", `Detected command: ${label}`);
    }
  }

  //
  // ------ Functionality ------
  //
  Timer {
    id: timerGetNumUpdates

    interval: root.updateInterval
    running: true
    repeat: true
    onTriggered: function () {
      getNumUpdates.running = true;
    }
  }

  function cmdGetNumUpdates() {
    if (root.customCmdGetNumUpdate !== "")
      return root.customCmdGetNumUpdate;

    for (let i = 0; i < root.updater.length; i++) {
      const e = root.updater[i];
      if (root[e.key] && e.cmdGetNumUpdates) {
        return e.cmdGetNumUpdates;
      }
    }

    Logger.e("UpdateCount", "Command to determine number of updates was not found/available.");
    return "printf '0\n'";
  }

  Process {
    id: getNumUpdates
    command: ["sh", "-c", root.cmdGetNumUpdates()]
    stdout: StdioCollector {
      onStreamFinished: {
        var count = parseInt(text.trim());
        root.updateCount = isNaN(count) ? 0 : count;
        Logger.i("UpdateCount", `Updates available: ${root.updateCount}`);
      }
    }
  }

  function startGetNumUpdates() {
    getNumUpdates.running = true;
  }

  function cmdDoSystemUpdate() {
    if (root.customCmdDoSystemUpdate != "") {
      return root.customCmdDoSystemUpdate;
    }

    for (let i = 0; i < root.updater.length; i++) {
      const e = root.updater[i];
      if (root[e.key] && e.cmdDoSystemUpdate) {
        return e.cmdDoSystemUpdate;
      }
    }

    Logger.e("UpdateCount", "Command to do system update was not found/available.");
  }

  Process {
    id: doSystemUpdate
    command: ["sh", "-c", root.terminalCmd + " " + root.cmdDoSystemUpdate()]
  }

  function startDoSystemUpdate() {
    doSystemUpdate.running = true;
  }

  //
  // ------ Start ------
  //
  Component.onCompleted: {
    checkAvailableCommands.running = true;
  }
}
