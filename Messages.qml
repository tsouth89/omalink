import QtQuick
import QtQuick.Controls as Controls
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
  property var contacts: []
  property var selectedConversation: null
  property bool composing: false
  property string recipientQuery: ""
  property string recipientNumber: ""
  property string pendingNewNumber: ""
  property string pendingNewName: ""
  property string pendingNewBody: ""
  property var pendingConversation: null
  property var pendingOutgoing: null
  property int pendingSyncAttempts: 0
  property var messages: []
  property bool sending: false
  property string pendingReply: ""
  property string pendingThreadId: ""
  property string searchText: ""
  property bool loading: false
  property string error: ""
  property double nowMs: Date.now()

  readonly property var filteredConversations: Model.filterConversations(conversations, searchText)
  readonly property var filteredContacts: Model.filterContacts(contacts, recipientQuery).slice(0, 8)

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
    refreshContacts()
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    conversations = []
    contacts = []
    selectedConversation = null
    composing = false
    recipientQuery = ""
    recipientNumber = ""
    pendingNewNumber = ""
    pendingNewName = ""
    pendingNewBody = ""
    pendingConversation = null
    pendingOutgoing = null
    pendingSyncAttempts = 0
    refreshAfterNewMessage.stop()
    messages = []
    searchText = ""
    if (!sending) {
      pendingReply = ""
      pendingThreadId = ""
    }
    error = ""
  }

  function refresh() {
    if (composing) return
    if (selectedConversation) {
      openThread(selectedConversation)
      return
    }
    refreshConversations()
  }

  function refreshConversations() {
    if (deviceId === "" || conversationProcess.running) return
    if (!selectedConversation) loading = true
    error = ""
    conversationProcess.command = [helperPath, "conversations", deviceId]
    conversationProcess.running = true
  }

  function refreshContacts() {
    if (deviceId === "" || contactProcess.running) return
    contactProcess.command = [helperPath, "contacts", deviceId]
    contactProcess.running = true
  }

  function openThread(conversation) {
    if (!conversation || threadProcess.running) return
    var changingThread = !selectedConversation
      || String(selectedConversation.threadId) !== String(conversation.threadId)
    selectedConversation = conversation
    if (changingThread) messages = []
    if (pendingOutgoing
        && (String(conversation.threadId) === String(pendingOutgoing.threadId)
          || Model.conversationMatchesNumber(conversation, pendingOutgoing.number)))
      messages = Model.mergePendingOutgoing(messages, pendingOutgoing).messages
    loading = true
    error = ""
    threadProcess.command = [helperPath, "messages", deviceId, String(conversation.threadId)]
    threadProcess.running = true
  }

  function showConversations() {
    selectedConversation = null
    composing = false
    recipientQuery = ""
    recipientNumber = ""
    messages = []
    replyField.text = ""
    error = ""
    Qt.callLater(root.refresh)
  }

  function startCompose() {
    selectedConversation = null
    composing = true
    recipientQuery = ""
    recipientNumber = ""
    error = ""
    composeMessage.text = ""
    Qt.callLater(function() { recipientField.forceActiveFocus() })
  }

  function chooseContact(contact) {
    recipientQuery = String(contact.name || contact.number || "")
    recipientNumber = String(contact.number || "")
    Qt.callLater(function() { composeMessage.forceActiveFocus() })
  }

  function sendNewMessage() {
    var destination = recipientNumber !== "" ? recipientNumber : recipientField.text.trim()
    var message = composeMessage.text.trim()
    if (destination === "" || message === "" || sending) return
    sending = true
    pendingNewNumber = destination
    pendingNewName = recipientNumber !== "" ? recipientQuery : destination
    pendingNewBody = message
    error = ""
    newMessageProcess.command = [helperPath, "sms", deviceId, destination, message]
    newMessageProcess.running = true
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
    onTriggered: {
      if (!root.selectedConversation && !root.composing) root.refreshConversations()
    }
  }

  Process {
    id: conversationProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fetched = Model.parseConversations(text)
        if (root.pendingConversation) {
          var merged = Model.mergePendingConversation(fetched, root.pendingConversation)
          root.conversations = merged.conversations
          if (merged.resolved) {
            root.pendingConversation = null
            root.pendingSyncAttempts = 0
            refreshAfterNewMessage.stop()
          }
        } else {
          root.conversations = fetched
        }
      }
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
    id: contactProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.contacts = Model.parseContacts(text)
    }
  }

  Process {
    id: newMessageProcess
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = "Could not send message"
    }
    onExited: function(exitCode) {
      root.sending = false
      if (exitCode !== 0) {
        root.pendingNewNumber = ""
        root.pendingNewName = ""
        root.pendingNewBody = ""
        root.error = "Could not send message"
        return
      }
      var sentAt = Date.now()
      root.conversations = Model.upsertConversationAfterSms(
        root.conversations,
        root.pendingNewNumber,
        root.pendingNewName,
        root.pendingNewBody,
        sentAt)
      root.pendingConversation = root.conversations[0]
      root.pendingOutgoing = {
        number: root.pendingNewNumber,
        body: root.pendingNewBody,
        timestamp: sentAt,
        threadId: root.conversations[0].threadId
      }
      root.pendingSyncAttempts = 0
      root.composing = false
      root.recipientQuery = ""
      root.recipientNumber = ""
      root.pendingNewNumber = ""
      root.pendingNewName = ""
      root.pendingNewBody = ""
      composeMessage.text = ""
      refreshAfterNewMessage.start()
    }
  }

  Timer {
    id: refreshAfterNewMessage
    interval: 1800
    repeat: true
    onTriggered: {
      root.pendingSyncAttempts++
      root.refreshConversations()
      if (!root.pendingConversation || root.pendingSyncAttempts >= 6) stop()
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
      var replyConversation = root.selectedConversation
      root.pendingOutgoing = {
        number: replyConversation && replyConversation.addresses
          ? String(replyConversation.addresses[0] || "") : "",
        body: root.pendingReply,
        timestamp: sentAt,
        threadId: root.pendingThreadId
      }
      if (replyConversation
          && String(replyConversation.threadId) === root.pendingThreadId)
        root.messages = Model.mergePendingOutgoing(
          root.messages, root.pendingOutgoing).messages
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
      onStreamFinished: {
        var fetched = Model.parseMessages(text)
        if (root.pendingOutgoing
            && (String(root.selectedConversation.threadId) === String(root.pendingOutgoing.threadId)
              || Model.conversationMatchesNumber(root.selectedConversation, root.pendingOutgoing.number))) {
          var merged = Model.mergePendingOutgoing(fetched, root.pendingOutgoing)
          root.messages = merged.messages
          if (merged.resolved) root.pendingOutgoing = null
        } else {
          root.messages = fetched
        }
      }
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
        if (root.selectedConversation || root.composing) root.showConversations()
        else root.close()
      }
      Keys.onPressed: function(event) {
        if (!root.selectedConversation && !root.composing && (event.key === Qt.Key_Slash
            || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)))) {
          searchField.forceActiveFocus()
          event.accepted = true
        } else if (!root.selectedConversation && !root.composing && event.key === Qt.Key_PageDown) {
          conversationList.contentY = Math.min(
            Math.max(0, conversationList.contentHeight - conversationList.height),
            conversationList.contentY + conversationList.height * 0.85)
          event.accepted = true
        } else if (!root.selectedConversation && !root.composing && event.key === Qt.Key_PageUp) {
          conversationList.contentY = Math.max(0, conversationList.contentY - conversationList.height * 0.85)
          event.accepted = true
        } else if (!root.selectedConversation && !root.composing && event.key === Qt.Key_Home) {
          conversationList.positionViewAtBeginning()
          event.accepted = true
        } else if (!root.selectedConversation && !root.composing && event.key === Qt.Key_End) {
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
              visible: root.selectedConversation !== null || root.composing
              iconText: "󰁍"
              tooltipText: "Back to conversations"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.showConversations()
            }

            Text {
              Layout.fillWidth: true
              text: root.selectedConversation
                ? Model.conversationTitle(root.selectedConversation)
                : (root.composing ? "New message" : "Messages")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.bold: true
            }

            Button {
              visible: root.selectedConversation === null && !root.composing
              text: "New message"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.startCompose()
            }

            PanelActionButton {
              visible: !root.composing
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
            visible: root.error !== "" || (!root.composing && (root.loading || (root.selectedConversation ? root.messages.length === 0 : root.filteredConversations.length === 0)))
            Layout.fillWidth: true
            text: root.error !== "" ? root.error : (root.loading ? "Loading…" : (root.selectedConversation ? "No messages" : (root.searchText === "" ? "No conversations" : "No matches")))
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          RowLayout {
            visible: root.selectedConversation === null && !root.composing
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
            visible: root.selectedConversation === null && !root.composing
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: root.filteredConversations

            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

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
                onClicked: {
                  if (modelData.pending && (modelData.threadId === null || modelData.threadId === undefined)) {
                    root.error = "Waiting for the phone to create this thread…"
                    root.refresh()
                  } else {
                    root.openThread(modelData)
                  }
                }
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

          ColumnLayout {
            visible: root.composing
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.space(10)

            Text {
              text: "TO"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            TextField {
              id: recipientField
              Layout.fillWidth: true
              enabled: !root.sending
              placeholderText: "Contact name or phone number"
              text: root.recipientQuery
              foreground: root.foreground
              font.family: root.fontFamily
              onTextEdited: {
                root.recipientQuery = text
                root.recipientNumber = ""
              }
            }

            ListView {
              visible: root.filteredContacts.length > 0 && root.recipientNumber === ""
              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(contentHeight, Style.space(220))
              clip: true
              spacing: Style.space(3)
              model: root.filteredContacts

              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

              delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: contactRow.implicitHeight + Style.space(14)
                color: contactMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, Color.accent)
                  : "transparent"
                radius: Style.cornerRadius

                RowLayout {
                  id: contactRow
                  anchors.fill: parent
                  anchors.margins: Style.space(7)
                  spacing: Style.space(8)

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    text: modelData.number
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: contactMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.chooseContact(modelData)
                }
              }
            }

            Text {
              text: "MESSAGE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            Controls.TextArea {
              id: composeMessage
              Layout.fillWidth: true
              Layout.fillHeight: true
              enabled: !root.sending
              placeholderText: root.sending ? "Sending…" : "Write a message"
              color: root.foreground
              placeholderTextColor: root.dim
              selectionColor: Color.menu.selectedBackground
              selectedTextColor: Color.menu.selectedText
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: TextEdit.Wrap
              padding: Style.space(10)
              background: BorderSurface {
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16), 1)
                radius: Style.cornerRadius
              }
            }

            RowLayout {
              Layout.alignment: Qt.AlignRight
              spacing: Style.space(8)

              Button {
                text: "Cancel"
                enabled: !root.sending
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.showConversations()
              }

              Button {
                text: root.sending ? "Sending…" : "Send"
                enabled: !root.sending
                  && (root.recipientNumber !== "" || recipientField.text.trim() !== "")
                  && composeMessage.text.trim() !== ""
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.sendNewMessage()
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
              : root.composing
                ? "Choose a synced contact or enter a phone number · Esc to cancel"
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
