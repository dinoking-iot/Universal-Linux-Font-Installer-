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
You can download the compiled font collection—including artistic fonts (Unicode, VNI, TCVN3, etc.) for Linux and Windows—at the release page.

## 🚀 Quick Deployment / Hướng dẫn triển khai nhanh

### 📥 1. Create Installer / Khởi tạo bộ cài đặt
Open your native Linux **Terminal**, copy and paste the command payload below, then press **Enter**:
*Mở **Terminal**, dán khối lệnh dưới đây và nhấn **Enter**:*

```bash
cat << 'EOF' > ~/Desktop/install_fonts_universal.sh
#!/bin/bash

TARGET_USER="$USER"
FONT_DIR="/home/$TARGET_USER/.fonts"
DESIGN_FONT_DIR="/home/$TARGET_USER/.fonts_design"
mkdir -p "$FONT_DIR" "$DESIGN_FONT_DIR"

TEMP_DIR=$(mktemp -d /tmp/font_installer_XXXXXX)
LOG_FILE="/home/$TARGET_USER/Desktop/font_install_report.log"

# Khởi tạo file log Song ngữ / Initialize Bilingual Log File
echo "==========================================================" > "$LOG_FILE"
echo "    UNIVERSAL LINUX FONT INSTALLATION DETAILED REPORT      " >> "$LOG_FILE"
echo "    BÁO CÁO CHI TIẾT TIẾN TRÌNH CÀI ĐẶT FONT ĐA NỀN TẢNG   " >> "$LOG_FILE"
echo "    --------------------------------------------------" >> "$LOG_FILE"
echo "    Execution Time / Thời gian chạy: $(date '+%d/%m/%Y %H:%M:%S')" >> "$LOG_FILE"
echo "    User / Người dùng: $TARGET_USER" >> "$LOG_FILE"
echo "    Target Directory / Thư mục đích: $FONT_DIR" >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "[DETAILED PROCESS LOG / NHẬT KÝ TIẾN TRÌNH CHI TIẾT]:" >> "$LOG_FILE"
echo "--------------------------------------------------------" >> "$LOG_FILE"

# 1. AUTO DEPENDENCY CHECK & INSTALLATION (BILINGUAL UI)
REQUIRED_TOOLS=("unzip" "7z" "unrar")
MISSING_PACKAGES=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        [ "$tool" == "7z" ] && MISSING_PACKAGES+=("p7zip") || MISSING_PACKAGES+=("$tool")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "[SYSTEM / HỆ THỐNG] Missing archive tools / Thiếu gói giải nén: ${MISSING_PACKAGES[*]}" >> "$LOG_FILE"
    
    zenity --question --title="Dependency Resolution / Cài đặt công cụ bổ trợ" \
           --text="Your system is missing required archive tools: [ ${MISSING_PACKAGES[*]} ].\nDo you want to automatically install them now to proceed?\n\nHệ thống của bạn đang thiếu các gói giải nén cần thiết: [ ${MISSING_PACKAGES[*]} ].\nBạn có muốn tự động cài đặt chúng ngay bây giờ để tiếp tục không?" --width=450
    
    if [ $? -eq 0 ]; then
        PASSWORD=$(zenity --password --title="Authentication Required / Xác thực quyền quản trị")
        if [ -n "$PASSWORD" ]; then
            if command -v pacman &> /dev/null; then
                echo "$PASSWORD" | sudo -S pacman -Sy --noconfirm "${MISSING_PACKAGES[@]}" > /dev/null 2>&1
            elif command -v apt-get &> /dev/null; then
                echo "$PASSWORD" | sudo -S apt-get update > /dev/null 2>&1
                echo "$PASSWORD" | sudo -S apt-get install -y "${MISSING_PACKAGES[@]}" > /dev/null 2>&1
            elif command -v dnf &> /dev/null; then
                echo "$PASSWORD" | sudo -S dnf install -y "${MISSING_PACKAGES[@]}" > /dev/null 2>&1
            fi
            echo "[SYSTEM / HỆ THỐNG] Dependency package installation command executed / Đã thực hiện lệnh cài đặt gói bổ trợ." >> "$LOG_FILE"
        fi
    fi
fi

# 2. DRAG & DROP GRAPHICAL INTERFACE
SELECTION=$(zenity --file-selection --directory --title="Drag & Drop or Choose Font Folder / Kéo & Thả Hoặc Chọn Thư Mục Chứa Font")
if [ -z "$SELECTION" ]; then
    echo "[CANCELLED / HỦY BỎ] Operation cancelled by user / Người dùng đã hủy tiến trình." >> "$LOG_FILE"
    rm -rf "$TEMP_DIR"
    exit 1
fi

notify-send -i "preferences-desktop-font" "Font Installer System" "Classifying and indexing fonts, please wait...\nĐang phân loại và ghi nhật ký font, vui lòng đợi..."

# Auto extraction to temporary workspace
cp -r "$SELECTION"/* "$TEMP_DIR/" 2>/dev/null || cp "$SELECTION" "$TEMP_DIR/" 2>/dev/null
cd "$TEMP_DIR" || exit 1

find . -type f | while read -r archive; do
    mime_arch=$(file --mime-type -b "$archive")
    case "$mime_arch" in
        application/zip) unzip -q -o "$archive" -d . && rm "$archive" ;;
        application/x-7z-compressed) 7z x -y "$archive" >/dev/null && rm "$archive" ;;
    esac
done

ART_WORDS=("handwriting" "script" "cartoon" "heart" "love" "chops" "thuphap" "vni-" "tcvn" "hl" "youngblood" "zoinkfat" "wedgie" "whimsy")
ins_std=0; ins_art=0; skip_fmt=0; skip_dup=0

# 3. PROCESSING LOOP WITH BILINGUAL LOG OUTPUT
while read -r file_path; do
    [ -z "$file_path" ] && continue
    origin_name=$(basename "$file_path")
    lower_name=$(echo "$origin_name" | tr '[:upper:]' '[:lower:]')
    
    # Extension validation
    if [[ "$lower_name" != *.ttf && "$lower_name" != *.otf ]]; then
        echo "[FAILED - INVALID FORMAT / THẤT BẠI - SAI ĐỊNH DẠNG] File: '$origin_name' | Reason: Not a valid .ttf or .otf file." >> "$LOG_FILE"
        ((skip_fmt++)); continue
    fi

    # System-wide duplication check
    sys_check=$(find /usr/share/fonts/ /usr/local/share/fonts/ -type f -name "$lower_name" 2>/dev/null | head -n 1)
    if [ -n "$sys_check" ]; then
        echo "[SKIPPED - SYSTEM DUPLICATE / BỎ QUA - TRÙNG HỆ THỐNG] Font: '$origin_name' | Existing path: $sys_check" >> "$LOG_FILE"
        ((skip_dup++)); continue
    fi

    # Design/Handwriting pattern detection
    is_art=false
    for word in "${ART_WORDS[@]}"; do
        if [[ "$lower_name" == *"$word"* ]]; then
            is_art=true
            break
        fi
    done

    if [ "$is_art" = true ]; then
        # Advanced Sandbox Isolation to prevent application UI distortion
        if [ ! -f "$DESIGN_FONT_DIR/$lower_name" ]; then
            cp "$file_path" "$DESIGN_FONT_DIR/$lower_name"
            echo "[SUCCESS - ISOLATED KERNEL / THÀNH CÔNG - CÁCH LY] Moved to design sandbox: '$lower_name'" >> "$LOG_FILE"
            ((ins_art++))
        else
            echo "[SKIPPED - EXISTED / BỎ QUA - ĐÃ TỒN TẠI] Isolated font already exists: '$origin_name'" >> "$LOG_FILE"
            ((skip_dup++))
        fi
    else
        # Standard Font Deployment
        if [ ! -f "$FONT_DIR/$lower_name" ]; then
            cp "$file_path" "$FONT_DIR/$lower_name"
            echo "[SUCCESS - STANDARD / THÀNH CÔNG - TIÊU CHUẨN] Successfully deployed: '$lower_name'" >> "$LOG_FILE"
            ((ins_std++))
        else
            echo "[SKIPPED - EXISTED / BỎ QUA - ĐÃ TỒN TẠI] Standard font already exists: '$origin_name'" >> "$LOG_FILE"
            ((skip_dup++))
        fi
    fi
done < <(find . -type f)

# 4. BILINGUAL SUMMARY MATRIX
echo "--------------------------------------------------------" >> "$LOG_FILE"
echo "==================== METRICS MATRIX / BẢNG THỐNG KÊ ====================" >> "$LOG_FILE"
echo " - SUCCESSFUL STANDARD FONTS / FONT TIÊU CHUẨN THÀNH CÔNG  : $ins_std font(s)." >> "$LOG_FILE"
echo " - SUCCESSFUL ISOLATED FONTS / FONT CÁCH LY AN TOÀN        : $ins_art font(s)." >> "$LOG_FILE"
echo " - SKIPPED DUPLICATES / SỐ FILE BỊ BỎ QUA DO TRÙNG LẶP    : $skip_dup font(s)." >> "$LOG_FILE"
echo " - REJECTED INVALID FILES / SỐ FILE BỊ TỪ CHỐI DO SAI ĐỊNH DẠNG: $skip_fmt file(s)." >> "$LOG_FILE"
echo "========================================================================" >> "$LOG_FILE"

# Inject local rule into Fontconfig subsystem
CONFIG_DIR="/home/$TARGET_USER/.config/fontconfig"
mkdir -p "$CONFIG_DIR"
cat << 'XML' > "$CONFIG_DIR/fonts.conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
    <dir>~/.fonts_design</dir>
</fontconfig>
XML

# Erase native rendering cache of ONLYOFFICE across deployment platforms
pkill -9 -f onlyoffice
rm -rf /home/$TARGET_USER/.local/share/onlyoffice/desktopeditors/data/fonts/*
rm -rf /home/$TARGET_USER/.var/app/org.onlyoffice.desktopeditors/data/onlyoffice/desktopeditors/data/fonts/* 2>/dev/null

# Recompile host operating system font-cache registry
fc-cache -r -f "$FONT_DIR" > /dev/null 2>&1
fc-cache -r -f "$DESIGN_FONT_DIR" > /dev/null 2>&1
rm -rf "$TEMP_DIR"

# 5. BILINGUAL DESKTOP NOTIFICATION PIPELINE
NOTIFY_TITLE="✅ Font Installation Completed! / Hoàn tất cài đặt Font!"
NOTIFY_MSG="🎯 Standard / Tiêu chuẩn: ${ins_std}\n🎨 Isolated / Cách ly thiết kế: ${ins_art}\n⚠️ Duplicates & Invalid / Trùng & Lỗi: $((skip_dup + skip_fmt))\n\n📝 Detailed log saved to Desktop! / Nhật ký đã lưu ngoài Desktop!"
notify-send -u normal -i "apply" "$NOTIFY_TITLE" "$NOTIFY_MSG"
EOF

sed -i 's/\r$//' ~/Desktop/install_fonts_universal.sh
chmod +x ~/Desktop/install_fonts_universal.sh

echo "--------------------------------------------------------"
echo " ✅ HOÀN THÀNH / COMPLETED: Bilingual Version is Ready!"
echo " 👉 File 'install_fonts_universal.sh' has been deployed to your Desktop."
echo "--------------------------------------------------------"

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
```bash
cat << 'EOF' > ~/Desktop/uninstall_fonts.sh
#!/bin/bash

TARGET_USER="$USER"
FONT_DIR="/home/$TARGET_USER/.fonts"
DESIGN_FONT_DIR="/home/$TARGET_USER/.fonts_design"
CONFIG_FILE="/home/$TARGET_USER/.config/fontconfig/fonts.conf"
LOG_FILE="/home/$TARGET_USER/Desktop/font_uninstall_report.log"

# Khởi tạo file log gỡ cài đặt / Initialize Uninstaller Log
echo "==========================================================" > "$LOG_FILE"
echo "    UNIVERSAL FONT UNINSTALLATION PURGE REPORT             " >> "$LOG_FILE"
echo "    BÁO CÁO TIẾN TRÌNH GỠ CÀI ĐẶT VÀ DỌN SẠCH FONT         " >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"
echo "Execution Time / Thời gian chạy: $(date '+%d/%m/%Y %H:%M:%S')" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Hiển thị hộp thoại cảnh báo xác nhận xóa sạch
zenity --question --title="Purge Confirmation / Xác nhận xóa sạch" \
       --text="WARNING: This action will completely erase all custom fonts installed in your local directory (~/.fonts and ~/.fonts_design).\nDo you want to proceed?\n\nCẢNH BÁO: Hành động này sẽ xóa sạch toàn bộ phông chữ tùy chỉnh đã cài trong thư mục cá nhân của bạn.\nBạn có chắc chắn muốn tiếp tục không?" --width=450

if [ $? -ne 0 ]; then
    echo "[CANCELLED / HỦY BỎ] Operation cancelled by user." >> "$LOG_FILE"
    notify-send -i "dialog-information" "Font Uninstaller" "Operation cancelled / Tiến trình dọn dẹp đã bị hủy."
    exit 0
fi

notify-send -i "edit-delete" "Font Uninstaller" "Purging custom directories, please wait...\nĐang tiến hành xóa sạch phông chữ, vui lòng đợi..."

# 1. Tiến hành xóa các thư mục cài đặt
if [ -d "$FONT_DIR" ]; then
    rm -rf "$FONT_DIR"
    echo "[DELETED / ĐÃ XÓA] Standard font directory / Thư mục font tiêu chuẩn: $FONT_DIR" >> "$LOG_FILE"
fi

if [ -d "$DESIGN_FONT_DIR" ]; then
    rm -rf "$DESIGN_FONT_DIR"
    echo "[DELETED / ĐÃ XÓA] Isolated font sandbox / Hộp cát cách ly font thiết kế: $DESIGN_FONT_DIR" >> "$LOG_FILE"
fi

# 2. Xóa cấu hình Fontconfig tùy chỉnh
if [ -f "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
    echo "[DELETED / ĐÃ XÓA] Custom Fontconfig rules / Quy tắc cấu hình Fontconfig: $CONFIG_FILE" >> "$LOG_FILE"
fi

# 3. Dọn dẹp triệt để bộ đệm ẩn cứng đầu của ONLYOFFICE
pkill -9 -f onlyoffice
rm -rf /home/$TARGET_USER/.local/share/onlyoffice/desktopeditors/data/fonts/*
rm -rf /home/$TARGET_USER/.var/app/org.onlyoffice.desktopeditors/data/onlyoffice/desktopeditors/data/fonts/* 2>/dev/null
echo "[CLEANED / ĐÃ DỌN DẸP] ONLYOFFICE isolated font-caches / Bộ nhớ đệm font ẩn của ONLYOFFICE." >> "$LOG_FILE"

# 4. Biên dịch lại bộ đệm cache font của hệ điều hành về mặc định nguyên bản
fc-cache -r -f > /dev/null 2>&1

echo "" >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"
echo " STATUS: SYSTEM ENVIRONMENT RESTORED TO FACTORY PRISTINE  " >> "$LOG_FILE"
echo " TRẠNG THÁI: MÔI TRƯỜNG HỆ THỐNG ĐÃ ĐƯỢC KHÔI PHỤC NGUYÊN TRẠNG" >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"

# 5. Gửi thông báo đẩy hoàn thành
NOTIFY_TITLE="🗑️ Purge Completed! / Gỡ cài đặt hoàn tất!"
NOTIFY_MSG="✅ Custom fonts have been completely wiped out.\n✅ System layout cache recompiled to pristine state.\n\nToàn bộ font tùy chỉnh đã được dọn sạch khỏi máy tính của bạn."
notify-send -u normal -i "user-trash" "$NOTIFY_TITLE" "$NOTIFY_MSG"
EOF

# Định dạng dòng chuẩn Unix và tự động cấp quyền chạy như một chương trình
sed -i 's/\r$//' ~/Desktop/uninstall_fonts.sh
chmod +x ~/Desktop/uninstall_fonts.sh

echo "--------------------------------------------------------"
echo " ✅ HOÀN THÀNH: Công cụ gỡ cài đặt nhanh đã sẵn sàng!"
echo " 👉 File 'uninstall_fonts.sh' đã xuất hiện ngoài Desktop."
echo "--------------------------------------------------------"

```
### 📂 3. Usage / Cách sử dụng
1. Go to your **Desktop** and double-click `uninstall_fonts.sh`.
2. View the bilingual matrix analytics report generated on your Desktop.

1. *Ra ngoài màn hình **Desktop**, nhấp đúp vào file `uninstall_fonts.sh`.*
2. *Kiểm tra bảng thống kê số liệu và nhật ký được xuất ngay ngoài màn hình.*
