import QtQuick
import QtQuick.Controls

// ParameterRow.qml — label + control; stacks vertically when narrow
Item {
    id: root
    width: parent ? Math.max(0, parent.width) : 280

    property string label: "Parameter"
    property bool stacked: width < 200
    property real labelWidth: stacked ? width : Math.min(96, Math.max(64, width * 0.32))
    default property alias content: controlSlot.data

    // implicitHeight must not depend on height: rows that collapse with
    // `height: visible ? implicitHeight : 0` would otherwise stay at 0 forever
    // once hidden (e.g. Ripple/Stopband after switching the response)
    implicitHeight: stacked ? (labelText.implicitHeight + 4 + 32) : 34
    height: implicitHeight
    clip: true

    Text {
        id: labelText
        text: root.label
        width: root.stacked ? root.width : root.labelWidth
        height: root.stacked ? implicitHeight : parent.height
        anchors {
            left: parent.left
            top: parent.top
        }
        color: theme.secondaryText
        font.family: "Stack Sans Headline"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: root.stacked ? Text.WordWrap : Text.NoWrap
        maximumLineCount: 2
    }

    Item {
        id: controlSlot
        anchors {
            left: root.stacked ? parent.left : labelText.right
            leftMargin: root.stacked ? 0 : 8
            right: parent.right
            top: root.stacked ? labelText.bottom : parent.top
            topMargin: root.stacked ? 4 : 0
            bottom: parent.bottom
        }
        // Force children to fill control slot
        onChildrenChanged: {
            for (let i = 0; i < children.length; ++i) {
                const c = children[i]
                if (c && c.hasOwnProperty("anchors")) {
                    // width binding preferred for controls
                }
            }
        }
    }
}
