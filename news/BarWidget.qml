import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// News Bar Widget Component
Item {
  id: root

  property var pluginApi: null

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Get settings from configuration
  readonly property string apiKey: cfg.apiKey || defaults.apiKey || "YOUR_API_KEY_HERE"
  readonly property string country: cfg.country || defaults.country || "us"
  readonly property string category: cfg.category || defaults.category || "general"
  readonly property int refreshInterval: cfg.refreshInterval || defaults.refreshInterval || 30
  readonly property int maxHeadlines: cfg.maxHeadlines || defaults.maxHeadlines || 10
  readonly property int rollingSpeed: cfg.rollingSpeed || defaults.rollingSpeed || 50
  readonly property int widgetWidth: cfg.widgetWidth || defaults.widgetWidth || 300

  // News data (stored in Main singleton for sharing with Panel)
  property string allNewsText: ""

  // API configuration
  readonly property string baseUrl: "https://newsapi.org/v2"

  readonly property real visualContentWidth: {
    if (isVertical) return root.capsuleHeight;
    return widgetWidth;
  }

  readonly property real visualContentHeight: {
    if (!isVertical) return root.capsuleHeight;
    return root.capsuleHeight * 2;
  }

  readonly property real contentWidth: isVertical ? root.capsuleHeight : visualContentWidth
  readonly property real contentHeight: isVertical ? visualContentHeight : root.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Auto-refresh timer
  Timer {
    id: refreshTimer
    interval: refreshInterval * 60 * 1000
    running: apiKey !== "YOUR_API_KEY_HERE" && apiKey !== ""
    repeat: true
    onTriggered: fetchNews()
  }

  // Watch for when pluginApi becomes available
  onPluginApiChanged: {
    if (pluginApi && apiKey && apiKey !== "YOUR_API_KEY_HERE") {
      console.log("[News Plugin] PluginApi loaded, API key:", apiKey ? "configured" : "not configured");
      Qt.callLater(fetchNews);
    }
  }

  // Update combined news text when Main.newsData changes
  Connections {
    target: Main
    function onNewsDataChanged() {
      updateAllNewsText();
    }
  }

  // Fetch news when API key becomes available
  onApiKeyChanged: {
    console.log("[News Plugin] API key changed:", apiKey ? "configured" : "not configured");
    if (apiKey && apiKey !== "YOUR_API_KEY_HERE") {
      Qt.callLater(fetchNews);
    }
  }

  // Update combined news text
  function updateAllNewsText() {
    if (Main.newsData.length === 0) {
      allNewsText = ""
      return
    }
    
    var combined = ""
    for (var i = 0; i < Main.newsData.length; i++) {
      if (i > 0) combined += "  •  "
      combined += "[" + (i + 1) + "] " + (Main.newsData[i]?.title || "No headline")
    }
    allNewsText = combined
  }


  // Fetch news
  function fetchNews() {
    Main.isLoading = true
    Main.errorMessage = ""

    if (!apiKey || apiKey === "YOUR_API_KEY_HERE") {
      Main.errorMessage = "API key not configured"
      Main.isLoading = false
      console.log("[News Plugin] Error: API key not configured")
      return
    }

    var xhr = new XMLHttpRequest()
    var url = baseUrl + "/top-headlines?country=" + country + 
              "&category=" + category + 
              "&apiKey=" + apiKey

    console.log("[News Plugin] Fetching headlines - Category:", category)

    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        console.log("[News Plugin] Response received - Status:", xhr.status)

        if (xhr.status === 200) {
          try {
            var response = JSON.parse(xhr.responseText)
            if (response.status === "ok" && response.articles) {
              console.log("[News Plugin] Success: Fetched", response.articles.length, "articles")
              Main.newsData = response.articles.slice(0, maxHeadlines)
              Main.isLoading = false
              Main.errorMessage = ""
            } else {
              Main.errorMessage = response.message || "API error"
              Main.isLoading = false
              console.log("[News Plugin] API Error:", response.message || "Unknown error")
            }
          } catch (e) {
            Main.errorMessage = "Failed to parse response"
            Main.isLoading = false
            console.log("[News Plugin] Parse Error:", e.toString())
          }
        } else if (xhr.status === 401) {
          Main.errorMessage = "Invalid API key"
          Main.isLoading = false
          console.log("[News Plugin] Error: Invalid API key (401)")
        } else if (xhr.status === 429) {
          Main.errorMessage = "Rate limit exceeded"
          Main.isLoading = false
          console.log("[News Plugin] Error: Rate limit exceeded (429)")
        } else if (xhr.status === 0) {
          Main.errorMessage = "Network error"
          Main.isLoading = false
          console.log("[News Plugin] Error: Network error or CORS issue (0)")
        } else {
          Main.errorMessage = "HTTP error " + xhr.status
          Main.isLoading = false
          console.log("[News Plugin] Error: HTTP", xhr.status)
        }
      }
    }

    xhr.open("GET", url)
    xhr.send()
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Horizontal layout
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginS
      anchors.rightMargin: Style.marginS
      spacing: Style.marginXS
      visible: !isVertical

      // News icon
      Text {
        text: "📰"
        font.family: "Noto Color Emoji, sans-serif"
        font.pointSize: root.barFontSize * 1.2
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        Layout.alignment: Qt.AlignVCenter
      }

      // News content with scrolling
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        property string displayText: {
          if (Main.errorMessage !== "") return Main.errorMessage
          if (Main.isLoading) return "Loading news..."
          if (Main.newsData.length === 0) return "No news available"
          return allNewsText
        }

        NText {
          id: newsText
          y: (parent.height - height) / 2
          text: parent.displayText
          color: {
            if (Main.errorMessage !== "") return Color.mError
            return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          pointSize: root.barFontSize
          applyUiScale: false
          
          x: textAnimation.running ? 0 : (contentWidth > parent.width ? parent.width - contentWidth : 0)
          
          SequentialAnimation {
            id: textAnimation
            running: newsText.contentWidth > newsText.parent.width && !Main.isLoading && Main.errorMessage === ""
            loops: Animation.Infinite
            
            PauseAnimation { duration: 2000 }
            NumberAnimation {
              target: newsText
              property: "x"
              from: 0
              to: -(newsText.contentWidth - newsText.parent.width + 20)
              duration: newsText.contentWidth * rollingSpeed
              easing.type: Easing.Linear
            }
            PauseAnimation { duration: 1000 }
            NumberAnimation {
              target: newsText
              property: "x"
              to: 0
              duration: 500
            }
          }
        }
      }

      // Refresh button
      Text {
        text: "🔄"
        font.family: "Noto Color Emoji, sans-serif"
        font.pointSize: root.barFontSize * 0.9
        color: refreshMouseArea.containsMouse ? Color.mPrimary : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
          id: refreshMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            mouse.accepted = true
            fetchNews()
          }
        }
      }
    }

    // Vertical layout (simplified)
    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: isVertical

      Text {
        text: "📰"
        font.family: "Noto Color Emoji, sans-serif"
        font.pointSize: root.barFontSize * 1.2
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        Layout.alignment: Qt.AlignHCenter
      }

      NText {
        text: Main.newsData.length > 0 ? Main.newsData.length.toString() : "?"
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        pointSize: root.barFontSize * 0.65
        applyUiScale: false
        Layout.alignment: Qt.AlignHCenter
      }
    }
  }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        // Open panel
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root);
        }
      } else if (mouse.button === Qt.RightButton) {
        // Open settings on right click
        if (pluginApi) {
          BarService.openPluginSettings(root.screen, pluginApi.manifest);
        }
      }
    }

    onEntered: {
      var tooltip = Main.newsData.length > 0 
        ? Main.newsData.length + " headlines\nLeft-click to view • Right-click for settings"
        : "Left-click to view • Right-click for settings";
      TooltipService.show(root, tooltip, BarService.getTooltipDirection());
    }

    onExited: {
      TooltipService.hide();
    }
  }

  Component.onCompleted: {
    // Only fetch if API key is already available
    if (apiKey && apiKey !== "YOUR_API_KEY_HERE") {
      fetchNews();
    }
  }
}
