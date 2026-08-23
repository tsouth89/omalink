import QtQuick
import qs.Commons

Item {
  id: root

  property int strength: -1
  property int sourceMaximum: 4
  property int barCount: 6
  property color activeColor: Color.foreground
  property color inactiveColor: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.22)

  readonly property int level: strength < 0
    ? 0
    : Math.max(0, Math.min(barCount, Math.round(strength * barCount / sourceMaximum)))

  implicitWidth: Style.space(24)
  implicitHeight: Style.space(14)

  Row {
    anchors.fill: parent
    spacing: Style.space(2)

    Repeater {
      model: root.barCount

      Item {
        required property int index
        width: (parent.width - parent.spacing * (root.barCount - 1)) / root.barCount
        height: parent.height

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: parent.height * (index + 1) / root.barCount
          radius: Math.min(width / 2, Style.space(1))
          color: index < root.level ? root.activeColor : root.inactiveColor
        }
      }
    }
  }
}
