import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../Components"

Item {
    anchors.fill: parent
    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.rightMargin: 50
        anchors.bottomMargin: 20
        anchors.topMargin: 20

        rows: 2
        columns: 2
        rowSpacing: 20
        columnSpacing: 20

        AnalockTile {
            id: analockTile
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ColumnLayout {
            spacing: 20
            Layout.columnSpan: 2
            Layout.rowSpan: 1
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 0
            Layout.column: 1

            DateTimeTile {}

            BatteryTile {
                id: batteryTile
            }

            PowerControls {
                onModeChanged: (index)=> {
                    batteryTile.vehicalMode = index
                }
                onPowerOff: root.powerOff()
            }
        }
    }
}
