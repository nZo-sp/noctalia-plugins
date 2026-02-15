import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  // Properties from bar widget
  property var newsData: []
  property string errorMessage: ""
  property bool isLoading: false

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: header.implicitHeight + Style.marginXL

        ColumnLayout {
          id: header
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            Text {
              text: "📰"
              font.family: "Noto Color Emoji, sans-serif"
              font.pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: "News Headlines"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "x"
              tooltipText: "Close"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: PanelService.closeFloatingPanel()
            }
          }
        }
      }

      // Content area
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM

        // Error message
        Rectangle {
          visible: errorMessage.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: errorRow.implicitHeight + (Style.marginXL)
          color: Qt.alpha(Color.mError, 0.1)
          radius: Style.radiusS
          border.width: Style.borderS
          border.color: Color.mError

          RowLayout {
            id: errorRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            Text {
              text: "⚠️"
              font.pointSize: Style.fontSizeL
              color: Color.mError
            }

            NText {
              text: errorMessage
              color: Color.mError
              pointSize: Style.fontSizeS
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
          }
        }

        // Scrollable news list
        NScrollView {
          id: contentScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          reserveScrollbarSpace: false
          gradientColor: Color.mSurface

          ColumnLayout {
            id: contentColumn
            width: contentScroll.availableWidth
            spacing: Style.marginM

            // Loading state
            NBox {
              visible: isLoading
              Layout.fillWidth: true
              Layout.preferredHeight: loadingColumn.implicitHeight + Style.marginXL

              ColumnLayout {
                id: loadingColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginL

                Item {
                  Layout.fillHeight: true
                }

                NBusyIndicator {
                  running: true
                  color: Color.mPrimary
                  size: Style.baseWidgetSize
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: "Loading news..."
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Empty state
            NBox {
              visible: !isLoading && newsData.length === 0 && errorMessage.length === 0
              Layout.fillWidth: true
              Layout.preferredHeight: emptyColumn.implicitHeight + Style.marginXL

              ColumnLayout {
                id: emptyColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginL

                Item {
                  Layout.fillHeight: true
                }

                Text {
                  text: "📰"
                  font.pointSize: 48
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: "No news available"
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // News list
            ColumnLayout {
              visible: !isLoading && newsData.length > 0
              width: parent.width
              spacing: Style.marginS

              NText {
                text: "Headlines (" + newsData.length + ")"
                pointSize: Style.fontSizeS
                color: Color.mSecondary
                font.weight: Style.fontWeightBold
                Layout.leftMargin: Style.marginS
              }

              Repeater {
                model: root.newsData

                NBox {
                  id: newsItem

                  Layout.fillWidth: true
                  Layout.leftMargin: Style.marginXS
                  Layout.rightMargin: Style.marginXS
                  implicitHeight: newsColumn.implicitHeight + (Style.marginL)

                  ColumnLayout {
                    id: newsColumn
                    width: parent.width - (Style.marginL)
                    x: Style.marginM
                    y: Style.marginM
                    spacing: Style.marginXS

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      // News number badge
                      Rectangle {
                        color: Color.mPrimary
                        radius: height * 0.5
                        width: Math.max(numberText.implicitWidth + (Style.marginS * 2), Style.baseWidgetSize * 0.6)
                        height: numberText.implicitHeight + (Style.marginXS * 2)

                        NText {
                          id: numberText
                          anchors.centerIn: parent
                          text: (index + 1).toString()
                          pointSize: Style.fontSizeXS
                          font.weight: Style.fontWeightBold
                          color: Color.mOnPrimary
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXXS

                        NText {
                          text: modelData.title || "No headline"
                          pointSize: Style.fontSizeM
                          font.weight: Style.fontWeightMedium
                          color: Color.mOnSurface
                          wrapMode: Text.Wrap
                          Layout.fillWidth: true
                        }

                        NText {
                          visible: modelData.description && modelData.description.length > 0
                          text: modelData.description || ""
                          pointSize: Style.fontSizeXS
                          color: Color.mOnSurfaceVariant
                          wrapMode: Text.Wrap
                          Layout.fillWidth: true
                          maximumLineCount: 2
                          elide: Text.ElideRight
                        }

                        NText {
                          visible: modelData.source && modelData.source.name
                          text: (modelData.source?.name || "") + (modelData.publishedAt ? " • " + formatTime(modelData.publishedAt) : "")
                          pointSize: Style.fontSizeXXS
                          color: Color.mSecondary
                          Layout.fillWidth: true
                        }
                      }
                    }

                    // Open link button
                    NButton {
                      visible: modelData.url && modelData.url.length > 0
                      text: "Open Article"
                      onClicked: {
                        Qt.openUrlExternally(modelData.url)
                      }
                    }
                  }

                  // Hover effect
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: parent.color = Qt.lighter(Color.mSurface, 1.05)
                    onExited: parent.color = Color.mSurface
                    onClicked: mouse.accepted = false
                    onPressed: mouse.accepted = false
                    onReleased: mouse.accepted = false
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  function formatTime(isoString) {
    try {
      var date = new Date(isoString)
      var now = new Date()
      var diffMs = now - date
      var diffMins = Math.floor(diffMs / 60000)
      
      if (diffMins < 60) return diffMins + "m ago"
      var diffHours = Math.floor(diffMins / 60)
      if (diffHours < 24) return diffHours + "h ago"
      var diffDays = Math.floor(diffHours / 24)
      if (diffDays < 7) return diffDays + "d ago"
      
      return date.toLocaleDateString()
    } catch (e) {
      return ""
    }
  }
}
