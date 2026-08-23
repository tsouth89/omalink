import QtQuick
import QtQuick.Controls
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
  property var selectedConversation: null
  property var messages: []
  property bool sending: false
  property string pendingReply: ""
  property string pendingThreadId: ""
  property string searchText: ""
  property bool loading: false
  property string error: ""
  property double nowMs: Date.now()

  readonly property var filteredConversations: Model.filterConversations(conversations, searchText)

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string helperPath: pluginDir + "/bin/omalink"
  readonly property color foreground: Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(String(payloadJson || "{}")) || {} } catch (parseError) { payload = {} }
    deviceId = String(payload.deviceId || "")
    searchText = ""
    opened = true
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    conversations = []
    selectedConversation = null
    messages = []
    searchText = ""
    if (!sending) {
      pendingReply = ""
      pendingThreadId = ""
    }
    error = ""
  }

  function refresh() {
    if (selectedConversation) {
      openThread(selectedConversation)
      return
    }
    if (deviceId === "" || conversationProcess.running) return
    loading = true
    error = ""
    conversationProcess.command = [helperPath, "conversations", deviceId]
    conversationProcess.running = true
  }

  function openThread(conversation) {
    if (!conversation || threadProcess.running) return
    selectedConversation = conversation
    messages = []
    loading = true
    error = ""
    threadProcess.command = [helperPath, "messages", deviceId, String(conversation.threadId)]
    threadProcess.running = true
  }

  function showConversations() {
    selectedConversation = null
    messages = []
    replyField.text = ""
    error = ""
    Qt.callLater(root.refresh)
  }

  function sendReply() {
    var message = replyField.text.trim()
    if (!selectedConversation || message === "" || sending) return
    sending = true
    pendingReply = message
    pendingThreadId = String(selectedConversation.threadId)
    error = ""
    replyProcess.command = [helperPath, "reply", deviceId, String(selectedConversation.threadId), message]
    replyProcess.running = true
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

  Process {
    id: replyProcess
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = "Could not send reply"
    }
    onExited: function(exitCode) {
      root.sending = false
      if (exitCode !== 0) {
        root.pendingReply = ""
        root.pendingThreadId = ""
        root.error = "Could not send reply"
        return
      }
      var sentAt = Date.now()
      if (root.selectedConversation
          && String(root.selectedConversation.threadId) === root.pendingThreadId)
        root.messages = Model.appendSentMessage(root.messages, root.pendingReply, sentAt)
      root.conversations = Model.updateConversationAfterSend(
        root.conversations,
        root.pendingThreadId,
        root.pendingReply,
        sentAt)
      root.pendingReply = ""
      root.pendingThreadId = ""
      replyField.text = ""
    }
  }

  Process {
    id: threadProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.messages = Model.parseMessages(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = "Could not load conversation"
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.error = "Could not load conversation"
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
      Keys.onEscapePressed: {
        if (root.selectedConversation) root.showConversations()
        else root.close()
      }
      Keys.onPressed: function(event) {
        if (!root.selectedConversation && (event.key === Qt.Key_Slash
            || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)))) {
          searchField.forceActiveFocus()
          event.accepted = true
        } else if (!root.selectedConversation && event.key === Qt.Key_PageDown) {
          conversationList.contentY = Math.min(
            Math.max(0, conversationList.contentHeight - conversationList.height),
            conversationList.contentY + conversationList.height * 0.85)
          event.accepted = true
        } else if (!root.selectedConversation && event.key === Qt.Key_PageUp) {
          conversationList.contentY = Math.max(0, conversationList.contentY - conversationList.height * 0.85)
          event.accepted = true
        } else if (!root.selectedConversation && event.key === Qt.Key_Home) {
          conversationList.positionViewAtBeginning()
          event.accepted = true
        } else if (!root.selectedConversation && event.key === Qt.Key_End) {
          conversationList.positionViewAtEnd()
          event.accepted = true
        } else if (event.key === Qt.Key_R) {
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

            PanelActionButton {
              visible: root.selectedConversation !== null
              iconText: "󰁍"
              tooltipText: "Back to conversations"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.showConversations()
            }

            Text {
              Layout.fillWidth: true
              text: root.selectedConversation ? Model.conversationTitle(root.selectedConversation) : "Messages"
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
            visible: root.loading || root.error !== "" || (root.selectedConversation ? root.messages.length === 0 : root.filteredConversations.length === 0)
            Layout.fillWidth: true
            text: root.error !== "" ? root.error : (root.loading ? "Loading…" : (root.selectedConversation ? "No messages" : (root.searchText === "" ? "No conversations" : "No matches")))
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          RowLayout {
            visible: root.selectedConversation === null
            Layout.fillWidth: true
            spacing: Style.space(8)

            TextField {
              id: searchField
              Layout.fillWidth: true
              placeholderText: "Search conversations"
              text: root.searchText
              foreground: root.foreground
              font.family: root.fontFamily
              onTextChanged: root.searchText = text
              Keys.onEscapePressed: {
                if (text !== "") text = ""
                else keyCatcher.forceActiveFocus()
              }
            }

            PanelActionButton {
              visible: root.searchText !== ""
              iconText: "󰅖"
              tooltipText: "Clear search"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                root.searchText = ""
                searchField.forceActiveFocus()
              }
            }
          }

          ListView {
            id: conversationList
            visible: root.selectedConversation === null
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: root.filteredConversations

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
                onClicked: root.openThread(modelData)
              }
            }
          }

          ListView {
            id: messageList
            visible: root.selectedConversation !== null
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(8)
            model: root.messages
            onCountChanged: positionViewAtEnd()

            delegate: Item {
              required property var modelData
              width: ListView.view.width
              height: bubble.implicitHeight

              Rectangle {
                id: bubble
                anchors.left: modelData.incoming ? parent.left : undefined
                anchors.right: modelData.incoming ? undefined : parent.right
                width: Math.min(messageText.implicitWidth + Style.space(24), parent.width * 0.78)
                implicitHeight: messageColumn.implicitHeight + Style.space(16)
                color: modelData.incoming
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : Color.menu.selectedBackground
                radius: Style.cornerRadius
                border.width: modelData.incoming ? 0 : 1
                border.color: Color.menu.selectedText

                ColumnLayout {
                  id: messageColumn
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(4)

                  Text {
                    id: messageText
                    Layout.fillWidth: true
                    text: modelData.body !== ""
                      ? modelData.body
                      : (modelData.attachmentCount > 0 ? "Attachment" : "")
                    color: modelData.incoming ? root.foreground : Color.menu.selectedText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                  }

                  Text {
                    Layout.alignment: Qt.AlignRight
                    text: Model.relativeTime(modelData.timestamp, root.nowMs)
                    color: modelData.incoming ? root.dim : Color.menu.selectedText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          RowLayout {
            visible: root.selectedConversation !== null
            Layout.fillWidth: true
            spacing: Style.space(8)

            TextField {
              id: replyField
              Layout.fillWidth: true
              enabled: !root.sending
              placeholderText: root.sending ? "Sending…" : "Reply"
              foreground: root.foreground
              font.family: root.fontFamily
              onAccepted: root.sendReply()
            }

            Button {
              text: "Send"
              enabled: !root.sending && replyField.text.trim() !== ""
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.sendReply()
            }
          }

          Text {
            Layout.fillWidth: true
            text: root.selectedConversation
              ? "Press Enter to send · R to refresh · Esc to go back"
              : root.filteredConversations.length + " of " + root.conversations.length
                + " conversations · / search · PgUp/PgDn · Home/End"
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
