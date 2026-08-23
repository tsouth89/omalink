import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property bool opened: false
  property string deviceId: ""
  property var conversations: []
  property bool loading: false
  property string error: ""
  property double nowMs: Date.now()

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string helperPath: pluginDir + "/bin/omalink"
  readonly property color foreground: Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(String(payloadJson || "{}")) || {} } catch (parseError) { payload = {} }
    deviceId = String(payload.deviceId || "")
    opened = true
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    conversations = []
    error = ""
  }

  function refresh() {
    if (deviceId === "" || conversationProcess.running) return
    loading = true
    error = ""
    conversationProcess.command = [helperPath, "conversations", deviceId]
    conversationProcess.running = true
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  Process {
    id: conversationProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.conversations = Model.parseConversations(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = "Could not load messages"
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.error = "Could not load messages"
    }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omalink-messages"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.62)
      MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_R) {
          root.refresh()
          event.accepted = true
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(Style.space(520), parent.width - Style.space(48))
        height: Math.min(Style.space(680), parent.height - Style.space(48))
        color: Color.popups.background
        radius: Style.cornerRadius

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(12)

          RowLayout {
            Layout.fillWidth: true

            Text {
              Layout.fillWidth: true
              text: "Messages"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.bold: true
            }

            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refresh()
            }

            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Close"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.close()
            }
          }

          Text {
            visible: root.loading || root.error !== "" || root.conversations.length === 0
            Layout.fillWidth: true
            text: root.error !== "" ? root.error : (root.loading ? "Loading conversations…" : "No conversations")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(4)
            model: root.conversations

            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width
              height: row.implicitHeight + Style.space(18)
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              radius: Style.cornerRadius

              RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: Style.space(9)
                spacing: Style.space(10)

                Rectangle {
                  width: Style.space(36)
                  height: width
                  radius: width / 2
                  color: Style.selectedFillFor(root.foreground, Color.accent)

                  Text {
                    anchors.centerIn: parent
                    text: "󰍩"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.icon
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)

                  RowLayout {
                    Layout.fillWidth: true
                    Text {
                      Layout.fillWidth: true
                      text: Model.conversationTitle(modelData)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: modelData.unread
                      elide: Text.ElideRight
                    }
                    Text {
                      text: Model.relativeTime(modelData.timestamp, root.nowMs)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: (modelData.incoming ? "" : "You: ") + modelData.preview
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.error = "Thread view is next"
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Read-only preview · Press R to refresh · Esc to close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
