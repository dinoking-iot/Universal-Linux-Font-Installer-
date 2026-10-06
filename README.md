# 🌐 Universal Linux Font Installer with Deep UI Protection Layer
## 🇻🇳 Bộ Cài Đặt Font Vạn Năng Cho Linux - Tự Động Cách Ly Chống Lỗi Giao Diện

A smart, secure, and cross-distribution Bash script designed to provide a **100% Graphical User Interface (GUI)** for managing custom typography on Linux, while actively shielding core desktop workflows and office applications (like **ONLYOFFICE**, **Google Chrome**, **Firefox**) against graphical layout distortion.

Một kịch bản Bash script thông minh, bảo mật và chạy xuyên nền tảng Linux, cung cấp **giao diện đồ họa (GUI) 100%** giúp đơn giản hóa việc cài đặt phông chữ, đồng thời chủ động bảo vệ hệ thống và các ứng dụng văn phòng tránh khỏi hiện tượng vỡ font giao diện hiển thị.

---

## ⚡ Core Features / Các tính năng cốt lõi

*   **100% GUI Drag & Drop (Zenity):** Double-click to execute, then drag and drop any font directory or archive file. No terminal knowledge required for end-users.
    *   *Kéo thả đồ họa 100%: Nhấp đúp chuột để khởi chạy và kéo thả thư mục/file nén phông chữ trực quan thông qua cửa sổ Zenity.*
*   **Deep Structural Sandbox Isolation:** Intelligently parses typography names and automatically isolates cursive, calligraphy, or legacy handwriting assets (e.g., VNI, TCVN3) inside an independent sandbox directory (`~/.fonts_design`). They remain fully selectable for document styling, but host application panels (like ONLYOFFICE) remain blind to them, preventing layout corruption.
    *   *Cách ly hộp cát chuyên sâu: Tự động phân loại các font chữ viết tay hoặc nghệ thuật dễ gây vỡ menu giao diện để đưa vào phân vùng độc lập (`~/.fonts_design`). Người dùng vẫn soạn thảo văn bản bình thường, nhưng giao diện phần mềm sẽ được bảo vệ tuyệt đối.*
*   **Dynamic Distro Package Resolution:** Autodetects host package managers (`apt-get`, `pacman`, `dnf`) and seamlessly installs missing archive backends (`unzip`, `p7zip`, `unrar`) in the background.
    *   *Khớp lệnh tự động theo hệ điều hành: Tự nhận diện Distro đang dùng (Ubuntu, Mint, Debian, Arch, BigLinux, Fedora...) để cài đặt ngầm các công cụ giải nén còn thiếu.*
*   **Filename Normalization & Anti-Duplication:** Automatically synchronizes typography filenames to lowercase and scrubs them against root directories (`/usr`) to skip pre-existing duplicates.
    *   *Chuẩn hóa & Khử trùng lặp: Ép toàn bộ tên file về chữ thường để Linux quản lý tối ưu, đồng thời quét loại bỏ các tệp trùng lặp có sẵn trong lõi hệ thống.*
*   **Bilingual Diagnostics Matrix:** Generates a dual-language metrics summary log file (`font_install_report.log`) on the user's Desktop and dispatches real-time native system notification bubbles.
    *   *Báo cáo & Thông báo song ngữ: Xuất tệp nhật ký trực quan ra màn hình Desktop song song hai ngôn ngữ và gửi thông báo đẩy thời gian thực.*

---

## 🚀 Quick Deployment / Hướng dẫn triển khai nhanh

### 📥 1. Create Installer / Khởi tạo bộ cài đặt
Open your native Linux **Terminal**, copy and paste the command payload below, then press **Enter**:
*Mở **Terminal**, dán khối lệnh dưới đây và nhấn **Enter**:*

```bash
cat << 'EOF' > ~/Desktop/install_fonts_universal.sh
#!/bin/bash
# [The Universal Bilingual Script Source Code goes here]
EOF
sed -i 's/\r$//' ~/Desktop/install_fonts_universal.sh
chmod +x ~/Desktop/install_fonts_universal.sh
```

### 📂 2. Usage / Cách sử dụng
1. Go to your **Desktop** and double-click `install_fonts_universal.sh`.
2. Drag and drop your typography folder/archive into the pop-up window and click **OK**.
3. View the bilingual matrix analytics report generated on your Desktop.

1. *Ra ngoài màn hình **Desktop**, nhấp đúp vào file `install_fonts_universal.sh`.*
2. *Kéo thả thư mục hoặc tệp nén chứa font vào cửa sổ pop-up hiển thị rồi bấm **OK**.*
3. *Kiểm tra bảng thống kê số liệu và nhật ký được xuất ngay ngoài màn hình.*

---

## 🗑️ Uninstaller Guide / Hướng dẫn gỡ cài đặt nhanh

If you wish to purge all custom fonts deployed by this installer and restore your system environment to its pristine factory state, please leverage the automated uninstaller component provided below.

*Nếu bạn muốn xóa sạch toàn bộ các phông chữ đã cài đặt bằng công cụ này để đưa môi trường hệ thống về lại trạng thái nguyên bản sạch sẽ, hãy sử dụng kịch bản gỡ cài đặt tự động dưới đây.*

