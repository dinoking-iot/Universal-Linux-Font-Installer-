🛡️ Universal Safe Font Installer & Diagnostics (install_fonts_universal.sh v3.2)

EN: A smart, zero-root font installer and diagnostic tool for any Linux distribution (built with BigLinux in mind, compatible with Arch, Debian/Ubuntu, Fedora, openSUSE, and immutable distros).

VI: Trình cài đặt font an toàn và công cụ chẩn đoán lỗi font không cần quyền root dành cho mọi bản phân phối Linux (tối ưu cho BigLinux, tương thích tốt với Arch, Debian/Ubuntu, Fedora, openSUSE và các hệ thống bất biến).

🚨 Why This Exists / Tại sao cần công cụ này?

EN: Bulk-installing thousands of design or legacy Vietnamese (VNI/TCVN) fonts on Linux frequently breaks browser UIs (Brave, Chrome) and system menus. Many custom fonts declare Arial or Helvetica in their internal metadata (font spoofing), tricking fontconfig into rendering web pages and interfaces in unreadable decorative or symbol glyphs.

VI: Việc cài hàng loạt font thiết kế hoặc font Việt hóa cũ (VNI/TCVN) trên Linux thường làm hỏng giao diện trình duyệt (Brave, Chrome) và hệ thống. Nhiều font tự khai báo tên nội bộ là Arial hoặc Helvetica (mạo danh font), đánh lừa fontconfig khiến toàn bộ chữ trên giao diện biến thành ký tự trang trí khó đọc.

✨ Key Features / Tính năng nổi bật

• 🔍 Static & Behavioral Preflight Audit / Kiểm tra tĩnh & mô phỏng hành vi:

EN: Inspects SFNT binary tables (name, cmap, OS/2, hhea) via Python and runs a live fc-match canary simulation before touching your system fonts.

VI: Phân tích cấu trúc bảng nhị phân của font bằng Python và chạy mô phỏng fc-match như trình duyệt trước khi cài đặt thực tế.

• 🚧 Smart Isolation (with-design-fonts) / Cách ly thông minh:

EN: Harmful fonts are moved to ~/.local/share/fonts-isolated instead of deleted. Launch specific apps with full access to isolated fonts anytime (e.g., with-design-fonts libreoffice).

VI: Các font gây hại được chuyển vào ~/.local/share/fonts-isolated thay vì xóa bỏ. Bạn vẫn có thể dùng chúng cho từng ứng dụng cụ thể khi cần (ví dụ: with-design-fonts libreoffice).

• 🩺 Font Doctor (--diagnose --fix) / Chế độ Bác sĩ chẩn đoán:

EN: Scans existing user fonts, installs missing baseline fonts (Noto, DejaVu, Liberation), cleans up broken fontconfig rules, and resets Brave browser custom font overrides safely.

VI: Quét toàn bộ font đã cài, tự động đề xuất cài bộ font nền còn thiếu (Noto, DejaVu, Liberation), dọn dẹp cấu hình fontconfig lỗi và đặt lại font mặc định cho Brave (có sao lưu).

• 📦 Recursive Extraction & Deduplication / Giải nén lồng nhau & lọc trùng:

EN: Automatically unpacks nested .zip, .rar, .7z, and .tar.* archives, discards corrupted files, and skips duplicates via SHA-1 hash and PostScript names.

VI: Tự động giải nén các file nén lồng nhiều lớp (.zip, .rar, .7z, .tar.*), loại bỏ file hỏng và bỏ qua font trùng lặp dựa trên mã băm SHA-1.

• 🖥️ Bilingual GUI & CLI / Giao diện đồ họa & Dòng lệnh song ngữ:

EN: Native English/Vietnamese Zenity dialogs with progress bars and persistent result summaries, plus full CLI support.

VI: Hỗ trợ hộp thoại đồ họa Zenity song ngữ Anh - Việt trực quan kèm thanh tiến trình, đồng thời hỗ trợ đầy đủ tham số dòng lệnh.

• 🔒 Safe & Reversible / An toàn & Dễ hoàn tác:

EN: Runs strictly as the current user (never root) and includes a clean --uninstall option.

VI: Chỉ hoạt động trong không gian người dùng hiện tại (tuyệt đối không chạy root) và hỗ trợ gỡ bỏ sạch sẽ qua lệnh --uninstall.

🚀 Usage / Hướng dẫn sử dụng


1. First Run / Chạy lần đầu tiên

EN: Browsers remove execute permissions from downloaded scripts. Open a terminal in your download folder and run once:

VI: Trình duyệt mặc định tắt quyền thực thi của file tải về. Hãy mở Terminal tại thư mục chứa file và chạy một lần duy nhất:

bash

bash install_fonts_universal.sh

(The script marks itself executable automatically so double-clicking works from the next run / Script sẽ tự cấp quyền thực thi để các lần sau bạn chỉ cần click đúp).

2. Commands & Options / Các lệnh và tùy chọn

bash

./install_fonts_universal.sh                    # Open GUI picker / Mở giao diện chọn file hoặc thư mục

./install_fonts_universal.sh /path/to/fonts.zip # Direct install / Cài trực tiếp từ file nén hoặc thư mục

./install_fonts_universal.sh --diagnose         # Check system fonts / Kiểm tra tình trạng font (chỉ đọc)

./install_fonts_universal.sh --diagnose --fix   # Fix font hijacking / Chẩn đoán và tự động cách ly font lỗi

./install_fonts_universal.sh --fix-brave-prefs  # Reset Brave fonts / Đặt lại font tùy chỉnh trên Brave

./install_fonts_universal.sh --clean            # Clean temp & backups / Dọn dẹp file tạm và bản sao lưu cũ

./install_fonts_universal.sh --uninstall        # Uninstall everything / Gỡ sạch toàn bộ những gì script đã cài

Additional Flags / Tùy chọn bổ sung:

• --strict: Also isolate cosmetic/legacy VNI/TCVN fonts (Cách ly cả các font trang trí hoặc font mã cũ VNI/TCVN).

• --cli: Run in terminal mode without GUI popups (Chạy thuần dòng lệnh, tắt hộp thoại đồ họa).

• -y, --yes: Auto-confirm all prompts (Tự động đồng ý mọi xác nhận).

• --dry-run: Simulate execution without modifying files (Chạy thử nghiệm, không ghi/xóa file).

🛠️ Requirements / Yêu cầu hệ thống

• Core / Bắt buộc: bash, fontconfig (fc-scan, fc-match, fc-list, fc-cache)

• Optional (Recommended) / Khuyên dùng: python3 (deep SFNT metadata audit / kiểm tra sâu cấu trúc font), zenity (GUI dialogs / giao diện đồ họa), unzip / p7zip / unrar (archive extraction / giải nén).

Download herr https://github.com/dinoking-iot/Universal-Linux-Font-Installer-/releases/tag/installfontsuniversal
