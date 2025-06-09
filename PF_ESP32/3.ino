/*
 * ESP32 OLED Controller
 * Kết nối với ứng dụng QML để hiển thị text trên màn hình OLED
 * Giao diện Amory by Nhom 3 - Tối ưu hiển thị
 */

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ESPmDNS.h>

// Cấu hình màn hình OLED
#define SCREEN_WIDTH 128    // Chiều rộng màn hình OLED (pixels)
#define SCREEN_HEIGHT 64    // Chiều cao màn hình OLED (pixels)
#define OLED_RESET    -1    // Pin Reset (không sử dụng)
#define SCREEN_ADDRESS 0x3C // Địa chỉ I2C của OLED

// Định nghĩa khu vực hiển thị
#define TOP_SECTION_HEIGHT 18   // Chiều cao phần trên (pixels) - tăng lên để hiển thị 2 dòng
#define BOTTOM_SECTION_HEIGHT (SCREEN_HEIGHT - TOP_SECTION_HEIGHT - 1) // Chiều cao phần dưới

// Cấu hình hiển thị văn bản
#define CHAR_WIDTH 6        // Chiều rộng trung bình của mỗi ký tự
#define CHAR_HEIGHT 8       // Chiều cao của mỗi ký tự
#define LINE_SPACING 1      // Khoảng cách giữa các dòng
#define MAX_CHARS_PER_LINE (SCREEN_WIDTH / CHAR_WIDTH) // Số ký tự tối đa mỗi dòng

// Khởi tạo đối tượng màn hình OLED
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Cấu hình WiFi
const char* ssid = "Mr Fresh";
const char* password = "64haitrieu";

// Cấu hình máy chủ web
WebServer server(80);

// Biến lưu trữ trạng thái
bool displayOn = true;
bool isConnected = false;  // Trạng thái kết nối
unsigned long lastToggleTime = 0;  // Thời gian cuối cùng chuyển đổi hiển thị
bool showIP = false;  // Flag để luân phiên hiển thị IP và "Đang chờ kết nối"
String topMessage = "Amory by Nhom 3";  // Nội dung phần trên
String bottomMessage = "Đang chờ kết nối.";  // Nội dung phần dưới

// Khởi tạo OLED
void setupOLED() {
  // Khởi tạo màn hình với điện áp 3.3V I2C
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 không tìm thấy"));
    for (;;); // Không tiếp tục nếu không tìm thấy màn hình
  }
  
  // Xóa bộ nhớ đệm hiển thị
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(F("Khoi dong..."));
  display.display();
  delay(1000);
}

// Hàm ngắt từ trong một chuỗi với kích thước tối đa
String* smartWordWrap(String text, int maxWidth, int maxLines, int& resultLines) {
  String* lines = new String[maxLines];
  resultLines = 0;
  
  int lineWidth = 0;
  String currentWord = "";
  String currentLine = "";
  
  for (unsigned int i = 0; i <= text.length(); i++) {
    char c = (i < text.length()) ? text.charAt(i) : ' '; // Thêm khoảng trắng ở cuối để xử lý từ cuối
    
    // Kiểm tra ký tự xuống dòng
    if (c == '\n') {
      if (currentWord.length() > 0) {
        if (lineWidth + currentWord.length() <= maxWidth) {
          currentLine += currentWord;
        } else {
          if (resultLines < maxLines) {
            lines[resultLines++] = currentLine;
          }
          currentLine = currentWord;
        }
      }
      
      if (resultLines < maxLines) {
        lines[resultLines++] = currentLine;
      }
      
      currentLine = "";
      currentWord = "";
      lineWidth = 0;
      continue;
    }
    
    // Tích lũy ký tự vào từ hiện tại
    if (c != ' ') {
      currentWord += c;
    } 
    // Hoàn thành một từ
    else if (currentWord.length() > 0) {
      // Kiểm tra độ dài của từ
      if (currentWord.length() > maxWidth) {
        // Từ quá dài, cần chia nhỏ
        int remain = currentWord.length();
        int pos = 0;
        
        while (remain > 0 && resultLines < maxLines) {
          int chunk = min(remain, maxWidth - lineWidth);
          
          if (lineWidth == 0 || lineWidth + chunk <= maxWidth) {
            currentLine += currentWord.substring(pos, pos + chunk);
            lineWidth += chunk;
            pos += chunk;
            remain -= chunk;
          }
          
          if (remain > 0 || i == text.length()) {
            lines[resultLines++] = currentLine;
            currentLine = "";
            lineWidth = 0;
          }
        }
        
        currentWord = "";
      } 
      // Từ bình thường
      else {
        // Kiểm tra xem thêm từ này có làm tràn dòng không
        if (lineWidth + currentWord.length() + 1 <= maxWidth) {
          // Thêm khoảng trắng nếu dòng không trống
          if (lineWidth > 0) {
            currentLine += " ";
            lineWidth++;
          }
          currentLine += currentWord;
          lineWidth += currentWord.length();
        } else {
          // Từ không vừa dòng hiện tại, xuống dòng mới
          if (resultLines < maxLines) {
            lines[resultLines++] = currentLine;
          }
          currentLine = currentWord;
          lineWidth = currentWord.length();
        }
        
        currentWord = "";
      }
    }
    
    // Kiểm tra kết thúc văn bản
    if (i == text.length() && currentLine.length() > 0 && resultLines < maxLines) {
      lines[resultLines++] = currentLine;
    }
  }
  
  return lines;
}

// Hiển thị giao diện chờ kết nối
void showWaitingInterface() {
  display.clearDisplay();
  
  // Phần trên - Logo Amory
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor((SCREEN_WIDTH - topMessage.length() * CHAR_WIDTH) / 2, 4); // Căn giữa
  display.println(topMessage);
  
  // Vẽ đường phân cách
  display.drawLine(0, TOP_SECTION_HEIGHT, SCREEN_WIDTH, TOP_SECTION_HEIGHT, SSD1306_WHITE);
  
  // Phần dưới - Luân phiên giữa "Đang chờ kết nối" và IP
  display.setCursor(0, TOP_SECTION_HEIGHT + 4);
  
  if (showIP) {
    display.println("IP: " + WiFi.localIP().toString());
  } else {
    display.println(bottomMessage);
  }
  
  display.display();
}

// Cập nhật phần trên của màn hình
void updateTopSection(String message) {
  if (!displayOn || !isConnected) return;
  
  // Lưu nội dung hiện tại
  topMessage = message;
  
  // Xóa chỉ phần trên
  display.fillRect(0, 0, SCREEN_WIDTH, TOP_SECTION_HEIGHT, SSD1306_BLACK);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Tối đa 2 dòng cho phần trên
  int lineCount = 0;
  String* lines = smartWordWrap(message, MAX_CHARS_PER_LINE, 2, lineCount);
  
  for (int i = 0; i < lineCount; i++) {
    display.setCursor(0, i * (CHAR_HEIGHT + LINE_SPACING));
    display.println(lines[i]);
  }
  
  delete[] lines;
  
  // Vẽ đường phân cách
  display.drawLine(0, TOP_SECTION_HEIGHT, SCREEN_WIDTH, TOP_SECTION_HEIGHT, SSD1306_WHITE);
  
  display.display();
}

// Cập nhật phần dưới của màn hình
void updateBottomSection(String message) {
  if (!displayOn || !isConnected) return;
  
  // Lưu nội dung hiện tại
  bottomMessage = message;
  
  // Xóa chỉ phần dưới
  display.fillRect(0, TOP_SECTION_HEIGHT + 1, SCREEN_WIDTH, BOTTOM_SECTION_HEIGHT, SSD1306_BLACK);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Tối đa 5 dòng cho phần dưới (dựa trên chiều cao khu vực)
  int maxLines = BOTTOM_SECTION_HEIGHT / (CHAR_HEIGHT + LINE_SPACING);
  int lineCount = 0;
  String* lines = smartWordWrap(message, MAX_CHARS_PER_LINE, maxLines, lineCount);
  
  for (int i = 0; i < lineCount; i++) {
    display.setCursor(0, TOP_SECTION_HEIGHT + 2 + i * (CHAR_HEIGHT + LINE_SPACING));
    display.println(lines[i]);
  }
  
  delete[] lines;
  
  display.display();
}

// Bật/tắt màn hình
void toggleDisplay() {
  displayOn = !displayOn;
  
  if (displayOn) {
    display.ssd1306_command(SSD1306_DISPLAYON);
    if (isConnected) {
      updateTopSection(topMessage);
      updateBottomSection(bottomMessage);
    } else {
      showWaitingInterface();
    }
  } else {
    display.ssd1306_command(SSD1306_DISPLAYOFF);
  }
}

// Thiết lập trạng thái kết nối
void setConnected(bool connected) {
  isConnected = connected;
  
  if (isConnected) {
    // Khởi tạo giao diện đã kết nối với hai phần riêng biệt
    updateTopSection("Connected");
    updateBottomSection("Ready");
  } else {
    topMessage = "Amory by Nhom 3";
    bottomMessage = "Đang chờ kết nối.";
    showWaitingInterface();
  }
}

// Xử lý route /status - trả về trạng thái hiện tại
void handleStatus() {
  String status = "{\"display\":\"" + String(displayOn ? "on" : "off") + "\",";
  status += "\"connected\":\"" + String(isConnected ? "true" : "false") + "\",";
  status += "\"topMessage\":\"" + topMessage + "\",";
  status += "\"bottomMessage\":\"" + bottomMessage + "\",";
  status += "\"ip\":\"" + WiFi.localIP().toString() + "\"}";
  
  server.send(200, "application/json", status);
}

// Xử lý route /toggle - bật/tắt màn hình
void handleToggle() {
  toggleDisplay();
  server.send(200, "text/plain", displayOn ? "Display ON" : "Display OFF");
}

// Xử lý route /connect - thiết lập trạng thái kết nối
void handleConnect() {
  setConnected(true);
  server.send(200, "text/plain", "Connected");
}

// Xử lý route /disconnect - thiết lập trạng thái không kết nối
void handleDisconnect() {
  setConnected(false);
  server.send(200, "text/plain", "Disconnected");
}

// Xử lý route /updateTop - cập nhật tin nhắn phần trên
void handleUpdateTop() {
  if (server.hasArg("message")) {
    String message = server.arg("message");
    updateTopSection(message);
    server.send(200, "text/plain", "Top section updated");
  } else {
    server.send(400, "text/plain", "Missing message parameter");
  }
}

// Xử lý route /updateBottom - cập nhật tin nhắn phần dưới
void handleUpdateBottom() {
  if (server.hasArg("message")) {
    String message = server.arg("message");
    updateBottomSection(message);
    server.send(200, "text/plain", "Bottom section updated");
  } else {
    server.send(400, "text/plain", "Missing message parameter");
  }
}

// Xử lý route không tìm thấy
void handleNotFound() {
  String message = "Route not found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET) ? "GET" : "POST";
  message += "\nArguments: ";
  message += server.args();
  message += "\n";
  
  for (uint8_t i = 0; i < server.args(); i++) {
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }
  
  server.send(404, "text/plain", message);
}

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 OLED Controller Starting...");
  
  // Khởi tạo OLED
  Wire.begin(48,47);
  setupOLED();
  
  // Kết nối WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Đang kết nối WiFi");
  
  // Đợi kết nối WiFi
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.print("Đã kết nối WiFi, IP: ");
  Serial.println(WiFi.localIP());
  
  // Thiết lập mDNS
  if (MDNS.begin("esp32oled")) {
    Serial.println("mDNS responder đã khởi động");
  }
  
  // Cấu hình các route
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/toggle", HTTP_GET, handleToggle);
  server.on("/connect", HTTP_GET, handleConnect);
  server.on("/disconnect", HTTP_GET, handleDisconnect);
  server.on("/updateTop", HTTP_GET, handleUpdateTop);
  server.on("/updateBottom", HTTP_GET, handleUpdateBottom);
  server.onNotFound(handleNotFound);
  
  // Khởi động máy chủ web
  server.begin();
  Serial.println("Máy chủ HTTP đã khởi động");
  
  // Hiển thị giao diện chờ kết nối ban đầu
  setConnected(false);
}

void loop() {
  server.handleClient();
  
  // Kiểm tra thời gian để luân phiên hiển thị IP và thông báo chờ
  if (!isConnected && displayOn) {
    unsigned long currentTime = millis();
    if (currentTime - lastToggleTime > 3000) { // Thay đổi mỗi 3 giây
      lastToggleTime = currentTime;
      showIP = !showIP; // Chuyển đổi hiển thị
      showWaitingInterface();
    }
  }
  
  delay(10);
}
