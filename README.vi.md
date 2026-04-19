*Read this in other languages: [English](README.md), [Tiếng Việt](README.vi.md).*

---

# VM - Trình Quản Lý Máy Ảo QEMU trên macOS

Một ứng dụng Native macOS được xây dựng bằng **SwiftUI**, cung cấp giao diện đồ họa (GUI) trực quan để quản lý các máy ảo **QEMU**. Công cụ này được thiết kế để giả lập đa kiến trúc (ARM64 & x86_64) mượt mà trên cả máy Mac Apple Silicon và Intel.

## Tính năng nổi bật

- **Trải nghiệm Native macOS:** Giao diện tối giản với thanh điều hướng Sidebar chuẩn macOS.
- **Hỗ trợ Đa kiến trúc:** Chạy hệ điều hành Linux hoặc Windows trên cả kiến trúc `ARM64` và `x86_64`.
- **Tùy chỉnh Phần cứng:** Dễ dàng cấu hình số nhân CPU, dung lượng RAM và độ phân giải màn hình.
- **Quản lý QEMU Thông minh:** - Cho phép chuyển đổi giữa bản QEMU đóng gói sẵn (App Bundle) và bản cài trên hệ thống.
  - Tích hợp công cụ kiểm tra và cài đặt QEMU qua **Homebrew**.
- **Tiện ích Ổ đĩa:** Tạo ổ đĩa `.raw` trống, sao chép ổ đĩa có sẵn hoặc chuyển đổi định dạng qua `qemu-img`.

## Yêu cầu hệ thống

- **Hệ điều hành:** macOS 13.0 (Ventura) trở lên.
- **IDE:** Xcode 14+ để build từ mã nguồn.
- **Dependencies:** Khuyên dùng [Homebrew](https://brew.sh/) để quản lý QEMU trên hệ thống.

## Hướng dẫn sử dụng

1. **Mở dự án:** Mở file `VM.xcodeproj` bằng Xcode.
2. **Build và Chạy:** Nhấn `Cmd + R` để khởi chạy ứng dụng.

## Giấy phép & Trích nguồn

Dự án này bao gồm hai phần giấy phép riêng biệt:

1. **Mã nguồn ứng dụng:** Cấp phép theo [MIT License](LICENSE). Bạn được tự do sử dụng, chỉnh sửa và phân phối mã nguồn Swift/SwiftUI.
2. **Lõi Ảo hóa (QEMU):** Ứng dụng này sử dụng **[QEMU](https://www.qemu.org/)** để ảo hóa.
   - Các file thực thi QEMU được phân phối theo **GNU General Public License v2 (GPLv2)**.
   - Mã nguồn chính thức của QEMU có tại [QEMU GitLab Repository](https://gitlab.com/qemu-project/qemu).

---
*Phát triển bởi Nguyễn Vinh Hiển*
