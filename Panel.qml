import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omalink.phone"
  ipcTarget: "omalink.phone"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: phone.connected ? foreground : dim
  readonly property var notifications: phone.devices.length > 0 && Array.isArray(phone.devices[0].notifications)
    ? Model.visibleNotifications(phone.devices[0].notifications) : []
  property string shareDeviceId: ""
  property string shareDeviceName: ""
  property string notifReplyId: ""
  property string notifReplyTitle: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) phone.refresh()

  Service {
    id: phone
    settings: root.settings
    panelOpen: root.opened
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄜"
    foreground: root.iconColor
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) phone.refresh()
      else root.toggle()
    }
  }

  Rectangle {
    visible: root.notifications.length > 0
    anchors.top: button.top
    anchors.right: button.right
    anchors.topMargin: Style.space(2)
    width: Style.space(6)
    height: width
    radius: width / 2
    color: Color.accent
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(480))

    ColumnLayout {
      id: content
      anchors.fill: parent
      spacing: Style.space(12)

      PanelHero {
        Layout.fillWidth: true
        title: "OmaLink"
        meta: phone.actionStatus !== "" ? phone.actionStatus : phone.statusText
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: phone.connected ? 1.0 : 0.55
        iconComponent: Component {
          Text {
            text: "󰄜"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }
      }

      Text {
        visible: !phone.installed
        Layout.fillWidth: true
        text: "KDE Connect is required. Installation will be part of the guided OmaLink setup."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Text {
        visible: phone.installed && phone.devices.length === 0
        Layout.fillWidth: true
        text: "Open pairing, then approve this computer in the KDE Connect app on your Android phone."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Repeater {
        model: phone.devices

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: deviceRow.implicitHeight + Style.space(16)
          color: Style.selectedFillFor(root.foreground, Color.accent)
          radius: Style.cornerRadius

          RowLayout {
            id: deviceRow
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: "󰄜"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                text: Model.batteryText(modelData)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              RowLayout {
                visible: Model.connectivityText(modelData) !== "" || Model.signalStrength(modelData) >= 0
                spacing: Style.space(5)

                Text {
                  visible: text !== ""
                  text: Model.connectivityText(modelData)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                SignalBars {
                  visible: strength >= 0
                  strength: Model.signalStrength(modelData)
                  activeColor: root.foreground
                }
              }
            }

            Button {
              iconText: "󰅌"
              tooltipText: "Send clipboard"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: phone.sendClipboard(modelData.id)
            }

            Button {
              iconText: "󰌷"
              tooltipText: "Send text or link"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: {
                root.shareDeviceId = modelData.id
                root.shareDeviceName = modelData.name
                shareField.text = ""
                Qt.callLater(function() { shareField.forceActiveFocus() })
              }
            }

            Button {
              iconText: "󰏲"
              tooltipText: "Ring phone"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: phone.ring(modelData.id)
            }
          }
        }
      }

      ColumnLayout {
        visible: root.shareDeviceId !== ""
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Send text or link to " + root.shareDeviceName
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          TextField {
            id: shareField
            Layout.fillWidth: true
            placeholderText: "Text or https://…"
            foreground: root.foreground
            font.family: root.fontFamily
            onAccepted: if (text.trim() !== "") {
              phone.shareText(root.shareDeviceId, text.trim())
              root.shareDeviceId = ""
            }
          }

          Button {
            text: "Send"
            enabled: shareField.text.trim() !== ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: {
              phone.shareText(root.shareDeviceId, shareField.text.trim())
              root.shareDeviceId = ""
            }
          }

          Button {
            text: "Cancel"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.shareDeviceId = ""
          }
        }
      }

      RowLayout {
        visible: root.notifications.length > 0
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: "PHONE NOTIFICATIONS · " + root.notifications.length
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }

        Button {
          text: "Clear all"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: phone.dismissAllNotifications(phone.devices[0].id)
        }
      }

      ListView {
        visible: root.notifications.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Style.space(190))
        clip: true
        spacing: Style.space(6)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.notifications

        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        delegate: Rectangle {
          required property var modelData
          width: ListView.view.width
          implicitHeight: notificationRow.implicitHeight + Style.space(16)
          color: Style.selectedFillFor(root.foreground, Color.accent)
          radius: Style.cornerRadius

          MouseArea {
            visible: modelData.isConversation
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var deviceId = phone.devices[0].id
              root.close()
              bar.shell.summon("omalink.phone", JSON.stringify({
                deviceId: deviceId,
                conversationHint: modelData.title
              }))
            }
          }

          RowLayout {
            id: notificationRow
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Item {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)

              Image {
                anchors.fill: parent
                visible: modelData.iconPath !== ""
                source: visible ? "file://" + modelData.iconPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                visible: modelData.iconPath === ""
                text: "󰂚"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.icon
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              Text {
                Layout.fillWidth: true
                text: modelData.appName
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: modelData.title
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: modelData.text
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }

            Button {
              visible: modelData.replyable
              text: "Reply"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                root.notifReplyId = modelData.replyId
                root.notifReplyTitle = modelData.title !== "" ? modelData.title : modelData.appName
                notifReplyField.text = ""
                Qt.callLater(function() { notifReplyField.forceActiveFocus() })
              }
            }

            PanelActionButton {
              visible: modelData.dismissable
              iconText: "󰅖"
              tooltipText: "Dismiss on phone"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: phone.dismissNotification(phone.devices[0].id, modelData.id)
            }
          }
        }
      }

      ColumnLayout {
        visible: root.notifReplyId !== ""
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Reply to " + root.notifReplyTitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          TextField {
            id: notifReplyField
            Layout.fillWidth: true
            placeholderText: "Reply"
            foreground: root.foreground
            font.family: root.fontFamily
            onAccepted: if (text.trim() !== "") {
              phone.replyToNotification(phone.devices[0].id, root.notifReplyId, text.trim())
              root.notifReplyId = ""
            }
          }

          Button {
            text: "Send"
            enabled: notifReplyField.text.trim() !== ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: {
              phone.replyToNotification(phone.devices[0].id, root.notifReplyId, notifReplyField.text.trim())
              root.notifReplyId = ""
            }
          }

          Button {
            text: "Cancel"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.notifReplyId = ""
          }
        }
      }

      Button {
        visible: phone.installed
        Layout.alignment: Qt.AlignHCenter
        text: phone.devices.length === 0 ? "Open pairing" : "Manage devices"
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        onClicked: phone.openPairing()
      }

      Button {
        visible: phone.devices.length > 0
        Layout.alignment: Qt.AlignHCenter
        iconText: "󰍩"
        text: "Messages"
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        onClicked: {
          var deviceId = phone.devices[0].id
          root.close()
          bar.shell.summon("omalink.phone", JSON.stringify({ deviceId: deviceId }))
        }
      }
    }
  }
}
