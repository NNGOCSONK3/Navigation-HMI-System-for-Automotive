import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// Đổi từ ApplicationWindow thành Item để sử dụng như component
Item {
    id: root

    // Thuộc tính cho component
    property int originalWidth: 1600
    property int originalHeight: 1200

    // Tính toán tỷ lệ co giãn dựa trên kích thước thực tế so với kích thước gốc
    property real scaleFactor: Math.min(width / originalWidth, height / originalHeight)
    property bool compactMode: scaleFactor < 0.5

    // Background image
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "qrc:/icons/Background.png"
    }

    // Define MyButton component
    component MyButton: Button {
        id: control
        property string setIcon: ""
        property bool isGlow: false
        implicitHeight: isGlow ? 50 : 44
        implicitWidth: isGlow ? 50 : 44

        Image {
            anchors.centerIn: parent
            source: setIcon
            scale: control.pressed ? 0.9 : 1.0
            Behavior on scale { NumberAnimation { duration: 200 } }
        }

        background: Rectangle {
            implicitWidth: control.width
            implicitHeight: control.height
            Layout.fillWidth: true
            radius: width
            color: "transparent"
            border.width: 0
            border.color: "transparent"
            visible: false

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.Linear
                }
            }

            Rectangle {
                id: indicator
                property int mx
                property int my
                x: mx - width / 2
                y: my - height / 2
                height: width
                radius: width / 2
                color: isGlow ? Qt.lighter("#29BEB6") : Qt.lighter("#B8FF01")
            }
        }

        Rectangle {
            id: mask
            radius: width
            anchors.fill: parent
            visible: false
        }

        OpacityMask {
            anchors.fill: background
            source: background
            maskSource: mask
        }

        MouseArea {
            id: mouseArea
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
        }

        ParallelAnimation {
            id: anim
            NumberAnimation {
                target: indicator
                property: 'width'
                from: 0
                to: control.width * 1.5
                duration: 200
            }
            NumberAnimation {
                target: indicator
                property: 'opacity'
                from: 0.9
                to: 0
                duration: 200
            }
        }

        onPressed: function(mouse) {
            indicator.mx = mouseArea.mouseX
            indicator.my = mouseArea.mouseY
            anim.restart()
        }
    }

    // Define SideGauge component
    component SideGauge: Item {
        id: gauge

        // Public API properties to match original CircularGauge
        property real value: 0
        property real minimumValue: 0
        property real maximumValue: 100

        // Original property
        property string speedColor: "yellow"

        // Private properties for the gauge
        property real _startAngle: -155
        property real _endAngle: 155
        property real _angleRange: _endAngle - _startAngle
        property real outerRadius: Math.min(width, height) / 2
        property real arcAngle: 180
        property real arcRadius: 90

        // Function to map value to angle - Fixed calculation
        function valueToAngle(value) {
            return _startAngle + (Math.max(minimumValue, Math.min(maximumValue, value)) - minimumValue) * _angleRange / (maximumValue - minimumValue);
        }

        function angleToValue(angle) {
            return minimumValue + (angle - _startAngle) * (maximumValue - minimumValue) / _angleRange;
        }

        Rectangle {
            id: background
            implicitHeight: gauge.height
            implicitWidth: gauge.width
            color: "transparent"
            anchors.centerIn: parent
            radius: 360

            // Maximum limit marker
            Image {
                sourceSize: Qt.size(16, 17)
                source: "qrc:/img/maxLimit.svg"

                // Position the image using angle calculation
                x: arcRadius * Math.cos(Math.PI * arcAngle / 180)
                y: arcRadius * Math.sin(Math.PI * arcAngle / 180)

                anchors.bottom: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Bright green track line
            Canvas {
                id: circularCanva
                property int value: gauge.value

                anchors.fill: parent

                Component.onCompleted: requestPaint()

                function degreesToRadians(degrees) {
                    return degrees * (Math.PI / 180);
                }

                function createLinearGradient(ctx, start, end, colors) {
                    var gradient = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
                    for (var i = 0; i < colors.length; i++) {
                        gradient.addColorStop(i / (colors.length - 1), colors[i]);
                    }
                    return gradient;
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    // Define the gradient colors for the filled arc
                    var gradientColors = [
                                "#B8FF01",// Start color
                                "#B8FF01"  // End color
                            ];

                    // Calculate the start and end angles for the filled arc - match original formula
                    var startAngle = valueToAngle(gauge.minimumValue) - 90;
                    var endAngle = valueToAngle(250) - 90;

                    // Create a linear gradient
                    var gradient = createLinearGradient(ctx, { x: 0, y: 0 }, { x: outerRadius * 2, y: 0 }, gradientColors);

                    // Draw the bright green outer track
                    ctx.beginPath();
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = gradient;
                    ctx.arc(outerRadius,
                            outerRadius,
                            outerRadius - 57,
                            degreesToRadians(startAngle),
                            degreesToRadians(endAngle));
                    ctx.stroke();
                }
            }

            // Background arc - dark blue
            Canvas {
                property int value: gauge.value

                anchors.fill: parent

                Component.onCompleted: requestPaint()

                function degreesToRadians(degrees) {
                    return degrees * (Math.PI / 180);
                }

                function createLinearGradient(ctx, start, end, colors) {
                    var gradient = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
                    for (var i = 0; i < colors.length; i++) {
                        gradient.addColorStop(i / (colors.length - 1), colors[i]);
                    }
                    return gradient;
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    // Define the gradient colors for the filled arc
                    var gradientColors = [
                                "#163546",// Start color
                                "#163546"  // End color
                            ];

                    // Calculate the start and end angles for the filled arc - match original formula
                    var startAngle = valueToAngle(gauge.minimumValue) - 90;
                    var endAngle = valueToAngle(250) - 90;

                    // Create a linear gradient
                    var gradient = createLinearGradient(ctx, { x: 0, y: 0 }, { x: outerRadius * 2, y: 0 }, gradientColors);

                    // Draw the dark blue background arc
                    ctx.beginPath();
                    ctx.lineWidth = outerRadius * 0.15;
                    ctx.strokeStyle = gradient;
                    ctx.arc(outerRadius,
                            outerRadius,
                            outerRadius - 75,
                            degreesToRadians(startAngle),
                            degreesToRadians(endAngle));
                    ctx.stroke();
                }
            }

            // Value arc - this updates when value changes - colored gradient
            Canvas {
                id: valueCanvas
                property int value: gauge.value

                anchors.fill: parent

                // This will update the canvas when value changes
                Connections {
                    target: gauge
                    function onValueChanged() {
                        valueCanvas.requestPaint()
                    }
                }

                Component.onCompleted: requestPaint()

                function degreesToRadians(degrees) {
                    return degrees * (Math.PI / 180);
                }

                function createLinearGradient(ctx, start, end, colors) {
                    var gradient = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
                    for (var i = 0; i < colors.length; i++) {
                        gradient.addColorStop(i / (colors.length - 1), colors[i]);
                    }
                    return gradient;
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    // Define the gradient colors for the filled arc
                    var gradientColors = [
                                "#6369FF", // Start color
                                "#63FFFF", // Color
                                "#FFFF00", // Color
                                "#FF0000"  // End color
                            ];

                    // Calculate the start and end angles for the filled arc - match original formula
                    var startAngle = valueToAngle(gauge.minimumValue) - 90;
                    var endAngle = valueToAngle(gauge.value) - 90;

                    // Only draw if we have a positive value
                    if (gauge.value > minimumValue) {
                        // Create a linear gradient
                        var gradient = createLinearGradient(ctx, { x: 0, y: 0 }, { x: outerRadius * 2, y: 0 }, gradientColors);

                        // Draw the value arc with gradient colors
                        ctx.beginPath();
                        ctx.lineWidth = outerRadius * 0.15;
                        ctx.strokeStyle = gradient;
                        ctx.arc(outerRadius,
                                outerRadius,
                                outerRadius - 75,
                                degreesToRadians(startAngle),
                                degreesToRadians(endAngle));
                        ctx.stroke();
                    }
                }
            }

            // Draw tick marks
            Canvas {
                id: tickMarksCanvas
                anchors.fill: parent

                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    // Add tick marks around the outer edge
                    var tickCount = 25;
                    var tickLength = outerRadius * 0.05;
                    var tickWidth = outerRadius * 0.008;
                    var tickColor = "#B8FF01";

                    for (var i = 0; i < tickCount; i++) {
                        var angle = _startAngle + i * (_angleRange / (tickCount - 1));
                        var angleRad = (angle - 90) * (Math.PI / 180);

                        var outerX = outerRadius + (outerRadius - 20) * Math.cos(angleRad);
                        var outerY = outerRadius + (outerRadius - 20) * Math.sin(angleRad);
                        var innerX = outerRadius + (outerRadius - 20 - tickLength) * Math.cos(angleRad);
                        var innerY = outerRadius + (outerRadius - 20 - tickLength) * Math.sin(angleRad);

                        ctx.beginPath();
                        ctx.strokeStyle = tickColor;
                        ctx.lineWidth = tickWidth;
                        ctx.moveTo(outerX, outerY);
                        ctx.lineTo(innerX, innerY);
                        ctx.stroke();
                    }
                }
            }
        }

        // Needle - properly positioned and rotated
        Item {
            id: needleContainer
            z: 1  // Ensure needle is on top of all other elements
            anchors.centerIn: parent

            // Correct rotation based on value
            rotation: valueToAngle(gauge.value)

            // The needle itself
            Item {
                id: needleWrapper
                width: outerRadius * 2
                height: outerRadius * 2
                anchors.centerIn: parent

                // Use the original Rectangle 4 image as needle
                Image {
                    id: needle
                    source: "qrc:/img/Rectangle 4.svg"
                    width: outerRadius * 0.85
                    height: outerRadius * 0.75
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    anchors.bottomMargin: -3  // Slight adjustment to position the needle tip correctly

                    // Original image might be wide, so we'll maintain proportions while setting the width
                    fillMode: Image.PreserveAspectFit

                    // Add glow effect for better visibility
                    layer.enabled: true
                    layer.effect: Glow {
                        radius: 5
                        samples: 10
                        color: "white"
                        source: needle
                    }
                }
            }
        }

        // Center display
        Item {
            anchors.centerIn: parent
            z: 5  // Lower than needle but higher than background

            Image {
                id: outerCircle
                anchors.centerIn: parent
                source: "qrc:/img/Ellipse 1.svg"

                Image {
                    sourceSize: Qt.size(203, 203)
                    anchors.centerIn: parent
                    source: "qrc:/img/Subtract.svg"

                    Image {
                        z: 2
                        sourceSize: Qt.size(147, 147)
                        anchors.centerIn: parent
                        source: "qrc:/img/Ellipse 6.svg"

                        ColumnLayout {
                            anchors.centerIn: parent

                            Label {
                                text: gauge.value.toFixed(0)
                                font.pixelSize: 65
                                font.family: "Inter"
                                color: "#FFFFFF"
                                font.bold: Font.DemiBold
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Label {
                                text: "km/h"
                                font.pixelSize: 18
                                font.family: "Inter"
                                color: "#FFFFFF"
                                opacity: 0.4
                                font.bold: Font.Normal
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // Container để co giãn tất cả nội dung
    Item {
        id: scalableContainer
        anchors.centerIn: parent
        width: root.originalWidth
        height: root.originalHeight

        // Áp dụng tỷ lệ co giãn
        transform: Scale {
            xScale: root.scaleFactor
            yScale: root.scaleFactor
            origin.x: scalableContainer.width / 2
            origin.y: scalableContainer.height / 2
        }

        // Base Layer
        Image {
            id: baseLayer
            anchors.centerIn: parent
            sourceSize: Qt.size(1492, 717)
            source: "qrc:/icons/Base.svg"
            visible: !root.compactMode

            Image {
                id: topNavigation
                anchors {
                    bottom: navigation_car.top
                    bottomMargin: 50
                    horizontalCenter: parent.horizontalCenter
                }
                source: "qrc:/icons/Top Navigation.svg"
                visible: !root.compactMode

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 60
                    visible: !root.compactMode

                    MyButton {
                        setIcon: isGlow ? "qrc:/icons/light/bxs_music.svg" : "qrc:/icons/bxs_music.svg"
                        onClicked: isGlow = !isGlow
                    }
                    MyButton {
                        setIcon: isGlow ? "qrc:/icons/light/ep_menu.svg" : "qrc:/icons/ep_menu.svg"
                        onClicked: isGlow = !isGlow
                    }
                    MyButton {
                        isGlow: true
                        setIcon: isGlow ? "qrc:/icons/light/Car_Icon.svg" : "qrc:/icons/Car_icon.svg"
                        onClicked: isGlow = !isGlow
                    }
                    MyButton {
                        setIcon: isGlow ? "qrc:/icons/light/eva_phone-call-fill.svg" : "qrc:/icons/eva_phone-call-fill.svg"
                        onClicked: isGlow = !isGlow
                    }
                    MyButton {
                        setIcon: isGlow ? "qrc:/icons/light/clarity_settings-solid.svg" : "qrc:/icons/clarity_settings-solid.svg"
                        onClicked: isGlow = !isGlow
                    }
                }
            }

            SideGauge {
                id: leftGauge
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: parent.width / 11
                }
                property bool accelerating: false
                width: 400
                height: 400
                value: accelerating ? maximumValue : 0
                maximumValue: 250
                Component.onCompleted: forceActiveFocus()
                Behavior on value { NumberAnimation { duration: 1000 } }

                Keys.onSpacePressed: function(event) {
                    accelerating = true
                    event.accepted = true
                }
                Keys.onReturnPressed: function(event) {
                    rightGauge.accelerating = true
                    event.accepted = true
                }
                Keys.onReleased: function(event) {
                    if (event.key === Qt.Key_Space) {
                        accelerating = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return) {
                        rightGauge.accelerating = false
                        event.accepted = true
                    }
                }
            }

            Image {
                id: navigation_car
                visible: false
                anchors.centerIn: parent
                source: "qrc:/icons/Navigation.png"
            }

            RowLayout {
                id: speedLimit
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26.50 + 65
                visible: !root.compactMode

                Label {
                    text: "P"
                    font.pixelSize: 32
                    font.family: "Inter"
                    font.bold: Font.Normal
                    font.capitalization: Font.AllUppercase
                    color: "#FFFFFF"
                }

                Label {
                    text: "R"
                    font.pixelSize: 32
                    font.family: "Inter"
                    font.bold: Font.Normal
                    font.capitalization: Font.AllUppercase
                    opacity: 0.2
                    color: "#FFFFFF"
                }
                Label {
                    text: "N"
                    font.pixelSize: 32
                    font.family: "Inter"
                    font.bold: Font.Normal
                    font.capitalization: Font.AllUppercase
                    opacity: 0.2
                    color: "#FFFFFF"
                }
                Label {
                    text: "D"
                    font.pixelSize: 32
                    font.family: "Inter"
                    font.bold: Font.Normal
                    font.capitalization: Font.AllUppercase
                    opacity: 0.2
                    color: "#FFFFFF"
                }
            }

            Image {
                id: modelLabel
                anchors {
                    bottom: car.top
                    bottomMargin: 60
                    horizontalCenter: car.horizontalCenter
                }
                source: "qrc:/img/Model 3.png"
                visible: !root.compactMode
            }

            Image {
                id: headlights
                anchors {
                    bottom: car.top
                    bottomMargin: -60
                    horizontalCenter: car.horizontalCenter
                }
                source: "qrc:/icons/Headlights.svg"
                visible: !root.compactMode
            }

            Image {
                id: car
                anchors {
                    bottom: speedLimit.top
                    bottomMargin: 40
                    horizontalCenter: speedLimit.horizontalCenter
                }
                source: "qrc:/icons/Car.svg"
                visible: !root.compactMode
            }

            /*
              Left Road
            */
            Image {
                id: leftRoad
                width: 127
                height: 397
                anchors {
                    left: speedLimit.left
                    leftMargin: 100
                    bottom: parent.bottom
                    bottomMargin: 26.50 + 50
                }
                source: "qrc:/icons/Vector 2.svg"
                visible: !root.compactMode
            }

            RowLayout {
                id: speedIndicator
                spacing: 20
                visible: !root.compactMode

                anchors {
                    left: parent.left
                    leftMargin: 250
                    bottom: parent.bottom
                    bottomMargin: 26.50 + 65
                }

                RowLayout {
                    spacing: 1
                    Layout.topMargin: 10
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 31.25 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 62.5 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 93.75 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 125.25 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 156.5 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 187.75 ? leftGauge.speedColor : "#01E6DC"
                    }
                    Rectangle {
                        width: 20
                        height: 15
                        color: leftGauge.value.toFixed(0) > 219 ? leftGauge.speedColor : "#01E6DC"
                    }
                }

                Label {
                    text: leftGauge.value.toFixed(0) + " MPH "
                    font.pixelSize: 32
                    font.family: "Inter"
                    font.bold: Font.Normal
                    font.capitalization: Font.AllUppercase
                    color: "#FFFFFF"
                }
            }

            /*
              Right Road
            */
            Image {
                id: rightRoad
                width: 127
                height: 397
                anchors {
                    right: speedLimit.right
                    rightMargin: 100
                    bottom: parent.bottom
                    bottomMargin: 26.50 + 50
                }
                source: "qrc:/icons/Vector 1.svg"
                visible: !root.compactMode
            }

            SideGauge {
                id: rightGauge
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: parent.right
                    rightMargin: parent.width / 11
                }
                property bool accelerating: false
                width: 400
                height: 400
                value: accelerating ? maximumValue : 0
                maximumValue: 250
                visible: !root.compactMode
                Behavior on value { NumberAnimation { duration: 1000 } }
            }
        }

        // Hiển thị đồng hồ duy nhất khi ở chế độ compact
        SideGauge {
            id: compactGauge
            visible: root.compactMode
            anchors.centerIn: parent
            width: 500
            height: 500
            value: leftGauge.value
            maximumValue: 250
            Behavior on value { NumberAnimation { duration: 1000 } }

            // Hiển thị nút bên dưới đồng hồ compact
            Label {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.bottom
                    topMargin: 20
                }
                text: "Press SPACE to accelerate"
                color: "#FFFFFF"
                font.pixelSize: 24
            }
        }
    }

    // Add global key handler for when focus gets lost
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onSpacePressed: function(event) {
            leftGauge.accelerating = true
            event.accepted = true
        }
        Keys.onReturnPressed: function(event) {
            rightGauge.accelerating = true
            event.accepted = true
        }
        Keys.onEnterPressed: function(event) {
            rightGauge.accelerating = true
            event.accepted = true
        }
        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Space) {
                leftGauge.accelerating = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                rightGauge.accelerating = false
                event.accepted = true
            }
        }
    }

    // Hiển thị chỉ báo rằng đang ở chế độ compact
    Label {
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }
        text: "Compact Mode"
        color: "#FFFFFF"
        font.pixelSize: 20
        visible: root.compactMode
    }

    Component.onCompleted: {
        // Ensure we have focus for keyboard events
        keyHandler.forceActiveFocus()
    }
}

// Ví dụ cách sử dụng component này:
/*
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 1600
    height: 1200
    visible: true
    title: qsTr("Car Dashboard")
    color: "black"

    // Import từ file (ví dụ: CarDashboard.qml)
    CarDashboard {
        id: dashboard
        anchors.fill: parent
    }
}
*/
