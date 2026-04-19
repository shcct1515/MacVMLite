*Đọc bằng ngôn ngữ khác: [English](README.md), [Tiếng Việt](README.vi.md).*
# VM - QEMU Virtual Machine Manager for macOS

A native macOS application built with **SwiftUI** that provides a sleek and intuitive graphical user interface (GUI) to manage **QEMU** virtual machines. This tool is designed for seamless cross-architecture emulation (ARM64 & x86_64) on Apple Silicon and Intel Macs.

## Features

- **Native macOS Experience:** Clean Sidebar-based navigation and native controls.
- **Multi-Architecture Support:** Run Linux or Windows on both `ARM64` and `x86_64` architectures.
- **Hardware Customization:** Easily configure CPU cores, RAM allocation, and display resolution.
- **Smart QEMU Management:** - Switch between bundled QEMU binaries and system-wide installations.
  - Integrated status check and installation tools for QEMU via **Homebrew**.
- **Disk Utilities:** Create blank `.raw` disks, copy existing images, or convert formats using `qemu-img`.

## System Requirements

- **OS:** macOS 13.0 (Ventura) or later.
- **IDE:** Xcode 14+ for building from source.
- **Dependencies:** [Homebrew](https://brew.sh/) is recommended for managing system-wide QEMU.

## Getting Started

1. **Open the project:** Launch the `VM.xcodeproj` file in Xcode.
2. **Build and Run:** Press `Cmd + R` to start the application.

## Licensing & Attributions

This project involves two distinct licensing components:

1. **Application Source Code:** Licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute the Swift/SwiftUI code.
2. **Virtualization Core (QEMU):** This application utilizes **[QEMU](https://www.qemu.org/)** for emulation.
   - QEMU binaries are distributed under the **GNU General Public License v2 (GPLv2)**.
   - The official QEMU source code can be found at the [QEMU GitLab Repository](https://gitlab.com/qemu-project/qemu).

---
*Created by Nguyen Vinh Hien*
