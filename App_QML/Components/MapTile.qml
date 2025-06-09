import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Style 1.0
import QtPositioning
import "../controls"
import QtQuick.Window
import QtWebEngine
import QtWebChannel 1.0
import QtNetwork

Rectangle {
    id: mapContainerz
    color: "#151515"
    radius: 15

    // ===== PROPERTIES =====
    // Vị trí và điều hướng
    property var defaultLocation: QtPositioning.coordinate(15.975090029295503, 108.25482861440456)
    property var destinationLocation: defaultLocation
    property bool routeVisible: false

    // Mapbox configuration
    property string mapboxAccessToken: "pk.eyJ1Ijoibm5nb2Nzb25rMyIsImEiOiJjbTllNWY2czMxNnQ5MmxzZ295cGVvdm5sIn0.BjFbchrdTcris48kn_uXBA"
    // property string mapStyle: "mapbox://styles/mapbox/dark-v11" // dark theme that matches the app's style
    property string mapStyle: "mapbox://styles/mapbox/satellite-streets-v12"

    // Route data
    property var currentRoute: null
    property var currentStep: null
    property int currentStepIndex: 0

    // GPS Simulation
    property bool autoNavigationEnabled: false
    property int autoNavigationInterval: 2000 // 2 giây
    property bool simulationActive: false // Thuộc tính mới để kiểm soát xem mô phỏng có đang hoạt động hay không

    // Thông tin địa điểm
    property var selectedLocation: null
    property string selectedLocationName: ""
    property string selectedLocationAddress: ""
    property bool placeInfoVisible: false

    // ESP32 OLED Display properties
    property string deviceIP: "192.168.1.199" // IP mặc định của ESP32, có thể chỉnh sửa
    property bool espConnected: false // Trạng thái kết nối ESP32
    property bool espFirstConnection: true // Lần đầu kết nối
    property string currentStreetDisplay: "" // Đường hiện tại để hiển thị trên OLED
    property string nextStreetDisplay: "" // Đường tiếp theo để hiển thị trên OLED

    // ===== TIMERS =====
    // Timer cho GPS mô phỏng
    Timer {
        id: autoNavigationTimer
        interval: autoNavigationInterval
        repeat: true
        running: autoNavigationEnabled && directionsPanel.visible
        onTriggered: {
            if (currentRoute && currentRoute.legs && currentRoute.legs[0].steps) {
                if (currentStepIndex < currentRoute.legs[0].steps.length - 1) {
                    nextStep()
                }
            }
        }
    }

    // Timer kiểm tra trạng thái ESP32
    Timer {
        id: espStatusTimer
        interval: 10000 // Kiểm tra ESP32 mỗi 10 giây
        repeat: true
        running: true
        onTriggered: checkESPStatus()
    }

    // ===== ESP32 CONNECTION FUNCTIONS =====
    // Gửi request đến ESP32
    function sendESPRequest(endpoint, params, callback) {
        var xhr = new XMLHttpRequest()
        var url = "http://" + deviceIP + endpoint
        if (params) {
            url += "?" + params
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    if (callback) {
                        callback(xhr.responseText)
                    }
                } else {
                    console.log("ESP32 request failed:", xhr.status)
                    espConnected = false
                }
            }
        }

        xhr.onerror = function() {
            console.log("ESP32 network error")
            espConnected = false
        }

        xhr.open("GET", url, true)
        xhr.timeout = 5000  // Timeout 5 giây
        xhr.send()
    }

    // Kiểm tra trạng thái ESP32
    function checkESPStatus() {
        sendESPRequest("/status", null, function(response) {
            try {
                var statusData = JSON.parse(response)
                espConnected = (statusData.connected === "true")

                // Nếu là lần kết nối đầu tiên và chưa kết nối, thì tự động kết nối
                if (espFirstConnection && !espConnected) {
                    connectToESP()
                    espFirstConnection = false
                }

                // Hiển thị trạng thái
                if (espConnected) {
                    showMessage(infoText, "Hub đã kết nối", 2000)
                }
            } catch (e) {
                console.log("ESP32 status parsing error:", e)
            }
        })
    }

    // Kết nối đến ESP32
    function connectToESP() {
        sendESPRequest("/connect", null, function(response) {
            espConnected = true
            showMessage(infoText, "Đã kết nối với Hub", 2000)

            // Gửi thông báo ban đầu đến ESP32
            updateESPDisplay("Amory Navigation", "San sang dan duong")
        })
    }

    // Ngắt kết nối với ESP32
    function disconnectFromESP() {
        sendESPRequest("/disconnect", null, function(response) {
            espConnected = false
            showMessage(infoText, "Đã ngắt kết nối với Hub", 2000)
        })
    }

    // Cập nhật nội dung hiển thị trên ESP32 OLED
    function updateESPDisplay(topMessage, bottomMessage) {
        if (!espConnected) return

        // Chuyển đổi tiếng Việt sang không dấu cho ESP32
        var topNoAccent = removeVietnameseAccents(topMessage)
        var bottomNoAccent = removeVietnameseAccents(bottomMessage)

        // Gửi nội dung đến ESP32
        sendESPRequest("/updateTop", "message=" + encodeURIComponent(topNoAccent), function(response) {
            console.log("Updated ESP32 top section:", topNoAccent)

            // Sau khi cập nhật phần trên, cập nhật phần dưới
            sendESPRequest("/updateBottom", "message=" + encodeURIComponent(bottomNoAccent), function(response) {
                console.log("Updated ESP32 bottom section:", bottomNoAccent)
            })
        })
    }

    // Hàm loại bỏ dấu tiếng Việt
    function removeVietnameseAccents(str) {
        if (!str) return ""

        str = str.replace(/à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ/g, "a")
        str = str.replace(/è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ/g, "e")
        str = str.replace(/ì|í|ị|ỉ|ĩ/g, "i")
        str = str.replace(/ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ/g, "o")
        str = str.replace(/ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ/g, "u")
        str = str.replace(/ỳ|ý|ỵ|ỷ|ỹ/g, "y")
        str = str.replace(/đ/g, "d")
        str = str.replace(/À|Á|Ạ|Ả|Ã|Â|Ầ|Ấ|Ậ|Ẩ|Ẫ|Ă|Ằ|Ắ|Ặ|Ẳ|Ẵ/g, "A")
        str = str.replace(/È|É|Ẹ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ/g, "E")
        str = str.replace(/Ì|Í|Ị|Ỉ|Ĩ/g, "I")
        str = str.replace(/Ò|Ó|Ọ|Ỏ|Õ|Ô|Ồ|Ố|Ộ|Ổ|Ỗ|Ơ|Ờ|Ớ|Ợ|Ở|Ỡ/g, "O")
        str = str.replace(/Ù|Ú|Ụ|Ủ|Ũ|Ư|Ừ|Ứ|Ự|Ử|Ữ/g, "U")
        str = str.replace(/Ỳ|Ý|Ỵ|Ỷ|Ỹ/g, "Y")
        str = str.replace(/Đ/g, "D")

        return str
    }

    // ===== MAP & NAVIGATION FUNCTIONS =====
    // Hàm tái sử dụng để di chuyển đến bước hiện tại
    function moveToCurrentStep(duration) {
        if (!currentStep || !currentStep.maneuver || !currentStep.maneuver.location) return

        var lng = currentStep.maneuver.location[0]
        var lat = currentStep.maneuver.location[1]
        var bearing = currentStep.maneuver.bearing_after || 0

        mapWebView.runJavaScript(`
            map.easeTo({
                center: [${lng}, ${lat}],
                zoom: 16,
                bearing: ${bearing},
                duration: ${duration || 1500},
                easing: function (t) {
                    // Bezier curve for more natural GPS-like movement
                    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
                },
                animate: true
            });

            // Cập nhật vị trí của startMarker để mô phỏng di chuyển
            if (startMarker) {
                startMarker.setLngLat([${lng}, ${lat}]);
            }
        `)
    }

    // Hiển thị thông báo
    function showMessage(element, message, duration) {
        element.text = qsTr(message)
        element.parent.visible = true
        element.parent.timer.interval = duration || 3000
        element.parent.timer.restart()
    }

    // Tìm kiếm vị trí
    function searchLocation(query) {
        if (!query || query.trim() === "") {
            showMessage(errorText, "Vui lòng nhập địa chỉ hoặc tọa độ", 3000)
            return
        }

        // Kiểm tra nếu đầu vào là tọa độ
        let coordRegex = /^(-?\d+(\.\d+)?),\s*(-?\d+(\.\d+)?)$/
        let match = query.match(coordRegex)

        if (match) {
            let lng = parseFloat(match[3]) // Mapbox uses lng,lat order
            let lat = parseFloat(match[1])

            if (!isNaN(lat) && !isNaN(lng) &&
                lat >= -90 && lat <= 90 &&
                lng >= -180 && lng <= 180) {
                destinationLocation = QtPositioning.coordinate(lat, lng)
                mapWebView.runJavaScript(`
                    map.flyTo({
                        center: [${lng}, ${lat}],
                        zoom: 14,
                        duration: 2000,
                        easing: function (t) {
                            return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
                        }
                    });
                    if (destinationMarker) destinationMarker.setLngLat([${lng}, ${lat}]);
                    else {
                        destinationMarker = new mapboxgl.Marker({color: '#FF4081'})
                            .setLngLat([${lng}, ${lat}])
                            .addTo(map);
                    }

                    // Đóng thông tin địa điểm nếu đang mở
                    hideLocationInfo();
                `)
                return
            } else {
                showMessage(errorText, "Tọa độ không hợp lệ", 3000)
                return
            }
        }

        // Sử dụng Mapbox Geocoding API
        let geocodingUrl = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?access_token=${mapboxAccessToken}&limit=1`

        var xhr = new XMLHttpRequest()
        xhr.open("GET", geocodingUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.features && response.features.length > 0) {
                        var feature = response.features[0]
                        var lng = feature.center[0]
                        var lat = feature.center[1]

                        destinationLocation = QtPositioning.coordinate(lat, lng)

                        mapWebView.runJavaScript(`
                            map.flyTo({
                                center: [${lng}, ${lat}],
                                zoom: 14,
                                duration: 2000,
                                easing: function (t) {
                                    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
                                }
                            });
                            if (destinationMarker) destinationMarker.setLngLat([${lng}, ${lat}]);
                            else {
                                destinationMarker = new mapboxgl.Marker({color: '#FF4081'})
                                    .setLngLat([${lng}, ${lat}])
                                    .addTo(map);
                            }

                            // Đóng thông tin địa điểm nếu đang mở
                            hideLocationInfo();
                        `)

                        showMessage(infoText, "Đã tìm thấy: " + feature.place_name, 3000)
                    } else {
                        showMessage(errorText, "Không tìm thấy địa điểm", 3000)
                    }
                } else {
                    showMessage(errorText, "Lỗi tìm kiếm: " + xhr.status, 3000)
                }
            }
        }
        xhr.send()
    }

    // Tìm đường đi
    function findRoute() {
        if (!destinationLocation.isValid || !defaultLocation.isValid) {
            showMessage(errorText, "Điểm đến không hợp lệ", 3000)
            return
        }

        // Nếu đường đi đã vẽ và nút đã chuyển sang màu xanh lá, bắt đầu mô phỏng
        if (routeVisible && routeButton.isGreenMode) {
            startSimulation()
            return
        }

        // Sử dụng Mapbox Directions API
        var startLng = defaultLocation.longitude
        var startLat = defaultLocation.latitude
        var endLng = destinationLocation.longitude
        var endLat = destinationLocation.latitude

        var directionsUrl = `https://api.mapbox.com/directions/v5/mapbox/driving/${startLng},${startLat};${endLng},${endLat}?steps=true&geometries=geojson&access_token=${mapboxAccessToken}`

        var xhr = new XMLHttpRequest()
        xhr.open("GET", directionsUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.routes && response.routes.length > 0) {
                        var route = response.routes[0]
                        currentRoute = route

                        // Hiển thị đường đi
                        var coordinates = JSON.stringify(route.geometry.coordinates)
                        mapWebView.runJavaScript(`
                            if (map.getSource('route')) {
                                map.getSource('route').setData({
                                    'type': 'Feature',
                                    'properties': {},
                                    'geometry': {
                                        'type': 'LineString',
                                        'coordinates': ${coordinates}
                                    }
                                });
                            } else {
                                map.addSource('route', {
                                    'type': 'geojson',
                                    'data': {
                                        'type': 'Feature',
                                        'properties': {},
                                        'geometry': {
                                            'type': 'LineString',
                                            'coordinates': ${coordinates}
                                        }
                                    }
                                });

                                map.addLayer({
                                    'id': 'route',
                                    'type': 'line',
                                    'source': 'route',
                                    'layout': {
                                        'line-join': 'round',
                                        'line-cap': 'round'
                                    },
                                    'paint': {
                                        'line-color': '#3366FF',
                                        'line-width': 5,
                                        'line-opacity': 0.8
                                    }
                                });
                            }

                            // Fit the map to show the entire route
                            var bounds = new mapboxgl.LngLatBounds();
                            ${coordinates}.forEach(function(coord) {
                                bounds.extend(coord);
                            });
                            map.fitBounds(bounds, {
                                padding: 80,
                                duration: 2000,
                                easing: function (t) {
                                    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
                                }
                            });

                            // Đóng thông tin địa điểm nếu đang mở
                            hideLocationInfo();
                        `)

                        // Cập nhật thông tin đường đi
                        var distance = route.distance / 1000 // convert to km
                        var duration = Math.round(route.duration / 60) // convert to minutes

                        routeInfo.distance = distance.toFixed(1)
                        routeInfo.duration = duration
                        routeInfo.visible = true
                        routeVisible = true

                        // Hiển thị hướng dẫn chỉ đường chi tiết
                        if (route.legs && route.legs.length > 0 && route.legs[0].steps) {
                            currentStepIndex = 0
                            currentStep = route.legs[0].steps[0]
                            directionsPanel.visible = true
                            updateDirectionsDisplay()

                            // Kết nối và gửi thông tin chỉ đường ban đầu đến ESP32
                            if (!espConnected) {
                                connectToESP()
                            }
                        }

                        // Đường đi đã hiển thị, chuyển nút sang màu xanh lá
                        routeButton.isGreenMode = true

                    } else {
                        showMessage(errorText, "Không tìm thấy đường đi phù hợp", 3000)
                    }
                } else {
                    showMessage(errorText, "Lỗi tìm đường: " + xhr.status, 3000)
                }
            }
        }
        xhr.send()
    }

    // Bắt đầu mô phỏng di chuyển
    function startSimulation() {
        if (!currentRoute || !currentRoute.legs || currentRoute.legs.length === 0) return

        // Nếu mô phỏng đang chạy, dừng lại
        if (simulationActive) {
            simulationActive = false
            autoNavigationEnabled = false
            showMessage(infoText, "Đã dừng mô phỏng", 2000)
            return
        }

        // Bắt đầu mô phỏng
        currentStepIndex = 0
        currentStep = currentRoute.legs[0].steps[0]
        updateDirectionsDisplay()
        moveToCurrentStep(2000)

        // Bật tự động điều hướng
        simulationActive = true
        autoNavigationEnabled = true
        showMessage(infoText, "Bắt đầu mô phỏng hành trình", 2000)

        // Kết nối ESP32 nếu chưa kết nối
        if (!espConnected) {
            connectToESP()
        }
    }

    // Cập nhật hiển thị hướng dẫn
    function updateDirectionsDisplay() {
        if (!currentRoute || !currentRoute.legs || currentRoute.legs.length === 0) return

        var step = currentRoute.legs[0].steps[currentStepIndex]
        if (!step) return

        // Các biểu tượng cho các hướng khác nhau
        var directionIcons = {
            "straight": "↑",
            "slight right": "↗",
            "right": "→",
            "sharp right": "↘",
            "uturn": "↓",
            "sharp left": "↙",
            "left": "←",
            "slight left": "↖",
            "arrive": "⦿"
        }

        // Xác định icon hướng từ maneuver
        var direction = "↑" // Mặc định là đi thẳng
        if (step.maneuver && step.maneuver.modifier) {
            var modifier = step.maneuver.modifier.toLowerCase()
            if (directionIcons[modifier]) {
                direction = directionIcons[modifier]
            }
        }

        // Xử lý đặc biệt cho điểm đến
        if (step.maneuver && step.maneuver.type === "arrive") {
            direction = "⦿"
        }

        directionIcon.text = direction

        // Lấy tên đường hiện tại
        var streetName = ""
        if (step.name && step.name !== "") {
            streetName = step.name
        } else {
            streetName = "Không có tên đường"
        }

        // Khoảng cách tới bước tiếp theo
        var stepDistance = (step.distance / 1000).toFixed(1) // km

        // Cập nhật UI
        currentStreet.text = streetName
        distanceToNext.text = stepDistance + " km"

        // Hiển thị tên đường tiếp theo (nếu có)
        var nextStep = null
        var nextStepName = "đường tiếp theo"
        if (currentStepIndex < currentRoute.legs[0].steps.length - 1) {
            nextStep = currentRoute.legs[0].steps[currentStepIndex + 1]
            if (nextStep && nextStep.name && nextStep.name !== "") {
                nextStepName = nextStep.name
            }
        }

        // Tạo hướng dẫn
        var instruction = getDirectionInstruction(step, nextStepName)
        instructionText.text = instruction

        // Chuẩn bị nội dung cho ESP32 OLED
        // Phần trên: Đường hiện tại
        var topContent = "Dang o: " + streetName

        // Phần dưới: Hướng dẫn chuyển tiếp
        var bottomContent = ""
        if (step.maneuver) {
            var type = step.maneuver.type
            var modifier = step.maneuver.modifier || ""

            switch (type) {
                case "depart":
                    bottomContent = "Bat dau tren " + streetName
                    break
                case "turn":
                    bottomContent = "Re " + getVietnameseDirection(modifier) + " vao " + nextStepName
                    break
                case "continue":
                    bottomContent = "Di thang tren " + nextStepName
                    break
                case "merge":
                    bottomContent = "Nhap vao " + nextStepName
                    break
                case "arrive":
                    bottomContent = "Da den dich"
                    break
                default:
                    if (modifier) {
                        bottomContent = "Di " + getVietnameseDirection(modifier) + " vao " + nextStepName
                    } else {
                        bottomContent = "Di thang tren " + nextStepName
                    }
            }
        }

        // Cập nhật màn hình OLED của ESP32
        if (espConnected) {
            updateESPDisplay(topContent, bottomContent)
        }

        // Cập nhật tiến trình route
        var totalSteps = currentRoute.legs[0].steps.length
        var progress = (currentStepIndex + 1) / totalSteps
        progressBar.width = progress * progressBarContainer.width

        // Hiển thị thời gian còn lại
        var remainingTime = 0
        for (var i = currentStepIndex; i < currentRoute.legs[0].steps.length; i++) {
            remainingTime += currentRoute.legs[0].steps[i].duration
        }

        var minutes = Math.round(remainingTime / 60)
        estimatedArrival.text = minutes + " phút"
    }

    // Lấy hướng dẫn chi tiết từ maneuver
    function getDirectionInstruction(step, nextRoadName) {
        if (!step.maneuver) return "Tiếp tục đi thẳng"

        var type = step.maneuver.type
        var modifier = step.maneuver.modifier || ""

        switch (type) {
            case "depart":
                return "Bắt đầu hành trình trên " + step.name
            case "turn":
                return "Rẽ " + getVietnameseDirection(modifier) + " vào " + nextRoadName
            case "continue":
                return "Tiếp tục đi thẳng trên " + nextRoadName
            case "merge":
                return "Nhập vào " + nextRoadName
            case "arrive":
                return "Đã đến điểm đến"
            default:
                if (modifier) {
                    return "Đi " + getVietnameseDirection(modifier) + " vào " + nextRoadName
                }
                return "Tiếp tục đi thẳng trên " + nextRoadName
        }
    }

    // Chuyển đổi hướng sang tiếng Việt
    function getVietnameseDirection(modifier) {
        switch (modifier.toLowerCase()) {
            case "slight right": return "phải nhẹ"
            case "right": return "phải"
            case "sharp right": return "phải gắt"
            case "uturn": return "vòng lại"
            case "sharp left": return "trái gắt"
            case "left": return "trái"
            case "slight left": return "trái nhẹ"
            case "straight": return "thẳng"
            default: return "thẳng"
        }
    }

    // Chuyển đến bước tiếp theo
    function nextStep() {
        if (!currentRoute || !currentRoute.legs || !currentRoute.legs[0].steps) return

        if (currentStepIndex < currentRoute.legs[0].steps.length - 1) {
            currentStepIndex++
            currentStep = currentRoute.legs[0].steps[currentStepIndex]
            updateDirectionsDisplay()
            moveToCurrentStep()
        }
    }

    // Chuyển đến bước trước đó
    function prevStep() {
        if (!currentRoute || !currentRoute.legs || !currentRoute.legs[0].steps) return

        if (currentStepIndex > 0) {
            currentStepIndex--
            currentStep = currentRoute.legs[0].steps[currentStepIndex]
            updateDirectionsDisplay()
            moveToCurrentStep()
        }
    }

    // Reset đường đi
    function clearRoute() {
        mapWebView.runJavaScript(`
            if (map.getLayer('route')) {
                map.removeLayer('route');
            }
            if (map.getSource('route')) {
                map.removeSource('route');
            }
        `)
        routeInfo.visible = false
        directionsPanel.visible = false
        routeVisible = false
        currentRoute = null
        currentStep = null
        simulationActive = false
        autoNavigationEnabled = false
        routeButton.isGreenMode = false

        // Cập nhật ESP32 về trạng thái sẵn sàng
        if (espConnected) {
            updateESPDisplay("Amory Navigation", "San sang dan duong")
        }
    }

    // Reset bản đồ
    function resetMapView() {
        clearRoute()
        mapWebView.runJavaScript(`
            map.flyTo({
                center: [${defaultLocation.longitude}, ${defaultLocation.latitude}],
                zoom: 14,
                duration: 2000,
                easing: function (t) {
                    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
                }
            });
            if (destinationMarker) {
                destinationMarker.remove();
                destinationMarker = null;
            }

            // Đóng thông tin địa điểm nếu đang mở
            hideLocationInfo();
        `)
        destinationLocation = defaultLocation
        placeInfoVisible = false
    }

    // Hàm lấy thông tin địa điểm khi click
    function getLocationInfo(lng, lat) {
        // Sử dụng Mapbox Reverse Geocoding API để lấy thông tin địa điểm
        var reverseGeocodingUrl = `https://api.mapbox.com/geocoding/v5/mapbox.places/${lng},${lat}.json?access_token=${mapboxAccessToken}&limit=1`

        var xhr = new XMLHttpRequest()
        xhr.open("GET", reverseGeocodingUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.features && response.features.length > 0) {
                        var feature = response.features[0]

                        // Lấy tên địa điểm và địa chỉ đầy đủ
                        selectedLocationName = feature.text || "Địa điểm không xác định"
                        selectedLocationAddress = feature.place_name || ""
                        selectedLocation = QtPositioning.coordinate(lat, lng)

                        // Hiển thị thông tin địa điểm
                        placeInfoVisible = true
                    } else {
                        showMessage(errorText, "Không có thông tin về địa điểm này", 3000)
                    }
                } else {
                    showMessage(errorText, "Lỗi khi lấy thông tin địa điểm", 3000)
                }
            }
        }
        xhr.send()
    }

    // Hàm ẩn thông tin địa điểm
    function hideLocationInfo() {
        mapWebView.runJavaScript(`
            hideLocationInfo();
        `)
        placeInfoVisible = false
    }

    // ===== UI COMPONENTS =====
    // Nút cài đặt ESP32
    Rectangle {
        id: espSettingsButton
        z: 7
        width: 40
        height: 40
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        radius: 20
        color: Style.alphaColor("#252525", 0.9)

        Text {
            anchors.centerIn: parent
            text: "⚙️"
            color: "#FFFFFF"
            font.pixelSize: 20
        }

        MouseArea {
            anchors.fill: parent
            onClicked: espSettingsDialog.visible = true
        }
    }

    // Dialog cài đặt ESP32
    Rectangle {
        id: espSettingsDialog
        z: 10
        width: 300
        height: 200
        anchors.centerIn: parent
        color: Style.alphaColor("#252525", 0.95)
        radius: 10
        visible: false

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Text {
                text: "Cài đặt ESP32"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: "Địa chỉ IP:"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                    id: espIpInput
                    width: 150
                    height: 30
                    text: deviceIP
                    placeholderText: "192.168.x.x"
                    color: "#000000"
                    font.pixelSize: 14
                }
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: "Trạng thái:"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 15
                    height: 15
                    radius: 7.5
                    color: espConnected ? "#4CAF50" : "#F44336"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: espConnected ? "Đã kết nối" : "Chưa kết nối"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: 10

                Button {
                    text: "Kết nối"
                    width: 80
                    height: 35
                    enabled: !espConnected
                    onClicked: {
                        deviceIP = espIpInput.text
                        connectToESP()
                        espSettingsDialog.visible = false
                    }
                }

                Button {
                    text: "Ngắt kết nối"
                    width: 80
                    height: 35
                    enabled: espConnected
                    onClicked: {
                        disconnectFromESP()
                        espSettingsDialog.visible = false
                    }
                }

                Button {
                    text: "Đóng"
                    width: 80
                    height: 35
                    onClicked: {
                        deviceIP = espIpInput.text
                        espSettingsDialog.visible = false
                    }
                }
            }
        }
    }

    // WebEngineView để hiển thị bản đồ Mapbox
    WebEngineView {
        id: mapWebView
        anchors.fill: parent
        z: 4

        // Tạo HTML để hiển thị bản đồ Mapbox
        url: "about:blank"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                // Khởi tạo bản đồ Mapbox
                var defaultLng = defaultLocation.longitude
                var defaultLat = defaultLocation.latitude

                mapWebView.runJavaScript(`
                    // Add start marker after the map is loaded
                    startMarker = new mapboxgl.Marker({color: '#4CAF50'})
                        .setLngLat([${defaultLng}, ${defaultLat}])
                        .addTo(map);

                    // Add custom marker for center of the map
                    const el = document.createElement('div');
                    el.className = 'center-marker';
                    el.style.width = '10px';
                    el.style.height = '10px';
                    el.style.borderRadius = '50%';
                    el.style.backgroundColor = '#FF4081';
                    el.style.border = '2px solid white';
                    el.style.position = 'absolute';
                    el.style.top = '50%';
                    el.style.left = '50%';
                    el.style.transform = 'translate(-50%, -50%)';
                    el.style.zIndex = '100';

                    // Cross lines
                    const vLine = document.createElement('div');
                    vLine.style.width = '2px';
                    vLine.style.height = '20px';
                    vLine.style.backgroundColor = 'white';
                    vLine.style.position = 'absolute';
                    vLine.style.top = '50%';
                    vLine.style.left = '50%';
                    vLine.style.transform = 'translateX(-50%)';
                    vLine.style.zIndex = '99';

                    const hLine = document.createElement('div');
                    hLine.style.width = '20px';
                    hLine.style.height = '2px';
                    hLine.style.backgroundColor = 'white';
                    hLine.style.position = 'absolute';
                    hLine.style.top = '50%';
                    hLine.style.left = '50%';
                    hLine.style.transform = 'translateY(-50%)';
                    hLine.style.zIndex = '99';

                    document.body.appendChild(el);
                    document.body.appendChild(vLine);
                    document.body.appendChild(hLine);

                    // Update coordinates on map move
                    map.on('move', function() {
                        const center = map.getCenter();
                        window.mapCenter = {
                            lat: center.lat.toFixed(6),
                            lng: center.lng.toFixed(6)
                        };
                        if (window.QtQmlObject) {
                            window.QtQmlObject.updateCoordinates(center.lat.toFixed(6), center.lng.toFixed(6));
                        }
                    });

                    // Thêm sự kiện click vào bản đồ để hiển thị thông tin địa điểm
                    map.on('click', function(e) {
                        // Nếu đang trong chế độ mô phỏng hoặc đang hiển thị route, không xử lý click
                        if (window.QtQmlObject.isSimulationActive() || window.QtQmlObject.isRouteVisible()) {
                            return;
                        }

                        // Gửi tọa độ click về QML
                        if (window.QtQmlObject) {
                            window.QtQmlObject.handleMapClick(e.lngLat.lng, e.lngLat.lat);
                        }
                    });

                    // Hàm ẩn thông tin địa điểm
                    window.hideLocationInfo = function() {
                        // Chỉ để sử dụng từ QML
                    }
                `)
            }
        }

        Component.onCompleted: {
            var html = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no">
                <script src="https://api.mapbox.com/mapbox-gl-js/v2.14.1/mapbox-gl.js"></script>
                <link href="https://api.mapbox.com/mapbox-gl-js/v2.14.1/mapbox-gl.css" rel="stylesheet">
                <style>
                    body { margin: 0; padding: 0; }
                    #map { position: absolute; top: 0; bottom: 0; width: 100%; }
                </style>
            </head>
            <body>
                <div id="map"></div>
                <script>
                    mapboxgl.accessToken = '${mapboxAccessToken}';
                    var map = new mapboxgl.Map({
                        container: 'map',
                        style: '${mapStyle}',
                        center: [${defaultLocation.longitude}, ${defaultLocation.latitude}],
                        zoom: 14,
                        attributionControl: false // Ẩn thông tin bản quyền
                    });

                    // Global variables
                    var startMarker = null;
                    var destinationMarker = null;
                    var placeTempMarker = null;

                    // For QML communication
                    window.QtQmlObject = null;
                    window.mapCenter = {
                        lat: ${defaultLocation.latitude}.toFixed(6),
                        lng: ${defaultLocation.longitude}.toFixed(6)
                    };
                </script>
            </body>
            </html>
            `
            mapWebView.loadHtml(html)
        }

        // Bridge object between QML and JavaScript
        WebChannel {
            id: channel
            registeredObjects: [qmlBridge]
        }

        webChannel: channel
    }

    // QML object to bridge with JavaScript
    QtObject {
        id: qmlBridge

        WebChannel.id: "qtQmlObject"

        // For receiving coordinate updates from JavaScript
        signal updateCoordinates(string lat, string lng)

        // Bắt sự kiện click từ bản đồ
        signal handleMapClick(real lng, real lat)

        // Kiểm tra xem có đang trong chế độ mô phỏng không
        function isSimulationActive() {
            return simulationActive
        }

        // Kiểm tra xem có đang hiển thị route không
        function isRouteVisible() {
            return routeVisible
        }

        onUpdateCoordinates: {
            coordinateText.text = lat + ", " + lng
        }

        onHandleMapClick: {
            getLocationInfo(lng, lat)
        }
    }

    // Viền bản đồ
    Rectangle {
        z: 55
        color: "transparent"
        anchors.centerIn: parent
        width: parent.width + 15
        height: parent.height + 15
        radius: 15
        border.width: 10
        border.color: "#000000"
    }

    // Thanh tìm kiếm
    TextField {
        id: searchField
        z: 6
        width: 509
        height: 45
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#FFFFFF"
        font.family: "Lato"
        font.pixelSize: 14
        font.weight: Font.Bold
        placeholderText: qsTr("Nhập địa chỉ hoặc tọa độ")
        leftPadding: 45
        placeholderTextColor: Style.alphaColor("#FFFFFF", 0.5)

        background: Rectangle {
            anchors.fill: parent
            radius: 45
            color: Style.alphaColor("#252525", 0.9)
        }

        // Icon tìm kiếm
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            text: "🔍"
            color: "#FFFFFF"
            font.pixelSize: 16
            opacity: 0.7
        }

        onAccepted: searchLocation(text)
    }

    // Nút tìm kiếm
    Button {
        id: searchButton
        z: 6
        width: 90
        height: 40
        anchors.right: searchField.right
        anchors.rightMargin: 5
        anchors.verticalCenter: searchField.verticalCenter
        text: qsTr("Tìm")

        background: Rectangle {
            radius: 20
            color: "#3366FF"
        }

        contentItem: Text {
            text: searchButton.text
            font.pixelSize: 14
            font.weight: Font.Bold
            color: "#FFFFFF"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: searchLocation(searchField.text)
    }

    // Thông báo lỗi tìm kiếm
    Rectangle {
        id: searchErrorNotification
        z: 10
        width: errorText.width + 30
        height: 40
        anchors.top: searchField.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 20
        color: Style.alphaColor("#F44336", 0.9)
        visible: false

        Text {
            id: errorText
            anchors.centerIn: parent
            text: qsTr("Không tìm thấy địa điểm")
            color: "#FFFFFF"
            font.pixelSize: 14
        }

        property alias timer: errorTimer

        Timer {
            id: errorTimer
            interval: 3000
            onTriggered: searchErrorNotification.visible = false
        }
    }

    // Thông báo thành công khi tìm được địa điểm
    Rectangle {
        id: successNotification
        z: 10
        width: infoText.width + 30
        height: 40
        anchors.top: searchField.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 20
        color: Style.alphaColor("#4CAF50", 0.9)
        visible: false

        Text {
            id: infoText
            anchors.centerIn: parent
            text: qsTr("Đã tìm thấy")
            color: "#FFFFFF"
            font.pixelSize: 14
        }

        property alias timer: infoTimer

        Timer {
            id: infoTimer
            interval: 3000
            onTriggered: successNotification.visible = false
        }
    }

    // Panel chỉ đường chi tiết
    Rectangle {
        id: directionsPanel
        z: 7
        width: parent.width
        height: 80
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#2196F3"
        visible: false

        // Container cho nội dung
        Item {
            id: directionsContent
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15

            // Icon hướng di chuyển
            Rectangle {
                id: directionIconBg
                width: 50
                height: 50
                radius: 25
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"

                Text {
                    id: directionIcon
                    text: "↑"
                    font.pixelSize: 32
                    anchors.centerIn: parent
                    color: "#2196F3"
                }
            }

            // Thông tin chỉ đường
            Column {
                anchors.left: directionIconBg.right
                anchors.leftMargin: 15
                anchors.right: rightControls.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    id: instructionText
                    text: qsTr("Sử dụng làn bên phải để đi vào Sasank/S79 Road")
                    width: parent.width
                    elide: Text.ElideRight
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    id: currentStreet
                    text: qsTr("Sasank/S79 Road")
                    width: parent.width
                    elide: Text.ElideRight
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    opacity: 0.9
                }

                // Thanh tiến trình
                Rectangle {
                    id: progressBarContainer
                    width: parent.width
                    height: 3
                    color: Style.alphaColor("#FFFFFF", 0.3)
                    radius: 1.5

                    Rectangle {
                        id: progressBar
                        height: parent.height
                        width: parent.width * 0.4
                        radius: 1.5
                        color: "#FFFFFF"
                    }
                }
            }

            // Các thông tin bên phải
            Column {
                id: rightControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                width: 80

                Text {
                    id: distanceToNext
                    text: qsTr("500 m")
                    anchors.right: parent.right
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    spacing: 3

                    Text {
                        text: "⏱️"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                    }

                    Text {
                        id: estimatedArrival
                        text: qsTr("9 phút")
                        color: "#FFFFFF"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // Thông tin địa điểm
    Rectangle {
        id: placeInfoPanel
        z: 8
        width: parent.width * 0.9
        height: 120
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        color: Style.alphaColor("#252525", 0.95)
        radius: 10
        visible: placeInfoVisible

        // Hiệu ứng mờ dần khi hiện/ẩn
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 15

            Text {
                id: placeNameText
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: selectedLocationName
                font.pixelSize: 18
                font.bold: true
                color: "#FFFFFF"
                elide: Text.ElideRight
            }

            Text {
                id: placeAddressText
                anchors.top: placeNameText.bottom
                anchors.topMargin: 5
                anchors.left: parent.left
                anchors.right: parent.right
                text: selectedLocationAddress
                font.pixelSize: 14
                color: "#CCCCCC"
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                spacing: 10

                // Nút tìm đường đến đây
                Button {
                    width: 140
                    height: 40
                    text: qsTr("Tìm đường đến đây")

                    background: Rectangle {
                        radius: 20
                        color: "#3366FF"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (selectedLocation) {
                            destinationLocation = selectedLocation
                            placeInfoVisible = false
                            findRoute()
                        }
                    }
                }

                // Nút đóng panel
                Button {
                    width: 40
                    height: 40
                    text: "×"

                    background: Rectangle {
                        radius: 20
                        color: Style.alphaColor("#555555", 0.7)
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 20
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        placeInfoVisible = false
                    }
                }
            }
        }
    }

    // Indicator kết nối ESP32
    Rectangle {
        id: espConnectionIndicator
        z: 6
        width: espStatusText.width + 30
        height: 30
        anchors.right: parent.right
        anchors.top: espSettingsButton.bottom
        anchors.topMargin: 5
        anchors.rightMargin: 20
        radius: 15
        color: Style.alphaColor("#252525", 0.7)

        Row {
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: espConnected ? "#4CAF50" : "#F44336"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: espStatusText
                text: "Hub: " + (espConnected ? "Đã kết nối" : "Chưa kết nối")
                color: "#FFFFFF"
                font.pixelSize: 12
            }
        }
    }

    // Hiển thị tọa độ
    // Text {
    //     id: coordinateText
    //     z: 6
    //     anchors.left: parent.left
    //     anchors.bottom: parent.bottom
    //     anchors.leftMargin: 20
    //     anchors.bottomMargin: 80
    //     text: defaultLocation.latitude.toFixed(6) + ", " + defaultLocation.longitude.toFixed(6)
    //     color: "#FFFFFF"
    //     font.pixelSize: 12
    //     font.family: "Monospace"
    // }

    // Nút đến vị trí này
    Rectangle {
        id: goToLocationButton
        z: 6
        width: goToLocationText.width + 30
        height: 40
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        radius: 20
        color: Style.alphaColor("#252525", 0.9)

        Text {
            id: goToLocationText
            anchors.centerIn: parent
            text: qsTr("Đến Vị Trí Này")
            color: "#FFFFFF"
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                // Lấy tọa độ hiện tại từ JavaScript bridge
                mapWebView.runJavaScript(`
                    window.mapCenter;
                `, function(result) {
                    if (result) {
                        let currentCoords = result.lat + ", " + result.lng;
                        searchField.text = currentCoords;
                        searchLocation(currentCoords);
                    }
                });
            }

            // Hiệu ứng hover
            hoverEnabled: true
            onEntered: parent.color = Style.alphaColor("#353535", 0.9)
            onExited: parent.color = Style.alphaColor("#252525", 0.9)
        }
    }

    // Thông tin đường đi
    Rectangle {
        id: routeInfo
        z: 6
        width: 200
        height: 55
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        radius: 10
        color: Style.alphaColor("#252525", 0.9)
        visible: false

        property double distance: 0
        property int duration: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: qsTr("Khoảng cách: ") + routeInfo.distance + " km"
                color: "#FFFFFF"
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Thời gian: ") + routeInfo.duration + " phút"
                color: "#FFFFFF"
                font.pixelSize: 14
                font.bold: true
            }
        }
    }

    // Nút tìm đường đi / bắt đầu mô phỏng
    RoundButton {
        id: routeButton
        z: 6
        width: 50
        height: 50
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: resetButton.top
        anchors.bottomMargin: 10
        visible: destinationLocation.latitude !== defaultLocation.latitude ||
                 destinationLocation.longitude !== defaultLocation.longitude

        property bool isGreenMode: false // Thuộc tính để theo dõi trạng thái của nút

        background: Rectangle {
            radius: 25
            color: routeButton.isGreenMode ? "#4CAF50" : "#3366FF" // Thay đổi màu từ blue sang green khi có đường đi
        }

        contentItem: Text {
            text: "→"
            font.pixelSize: 24
            color: "#FFFFFF"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: findRoute() // Hàm này sẽ xử lý cả việc tìm đường và bắt đầu mô phỏng
    }

    // Nút hai chức năng: xóa đường đi hoặc về vị trí mặc định
    RoundButton {
        id: resetButton
        z: 6
        width: 50
        height: 50
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20

        background: Rectangle {
            radius: 25
            color: routeVisible ? Style.alphaColor("#F44336", 0.9) : Style.alphaColor("#252525", 0.9)
        }

        contentItem: Text {
            text: routeVisible ? "×" : "⌂"
            font.pixelSize: 24
            color: "#FFFFFF"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            if (routeVisible) {
                clearRoute()
            } else {
                resetMapView()
            }
        }
    }

    // Component initialization
    Component.onCompleted: {
        // Kiểm tra kết nối ESP32
        checkESPStatus()
    }
}
