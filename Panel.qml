import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omalink.phone"
  ipcTarget: "omalink.phone"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: phone.connected ? foreground : dim

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) phone.refresh()

  Service {
    id: phone
    settings: root.settings
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
                text: "Connected"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              text: "Ring"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: phone.ring(modelData.id)
            }
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
    }
  }
}
