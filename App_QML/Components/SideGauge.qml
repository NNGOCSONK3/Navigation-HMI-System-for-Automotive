// Đặt trong thư mục Components/SideGauge.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
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
