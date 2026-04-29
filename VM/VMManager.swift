//
//  VMManager.swift
//  VM
//
//  Created by Nguyễn Vinh Hiển on 17/4/26.
//

import AppKit
import Combine
import SwiftUI

class VMManager: ObservableObject {
    @Published var vms: [UniversalVMConfig] = []
    @Published var isConverting: Bool = false
    @Published var conversionProgress: Double = 0.0
    @Published var conversionLabel: String = ""
    
    @AppStorage("useBundledQEMU") var useBundledQEMU: Bool = true
    private var activeProcesses: [UUID: Process] = [:]
    
    // MARK: - Utilities
    private func getQEMUBinaryPath(name: String) -> URL? {
        if useBundledQEMU {
            if let fileURL = Bundle.main.url(forResource: name, withExtension: nil) {
                return fileURL
            }
            return nil
        } else {
            let path = "/opt/homebrew/bin/\(name)"
            return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
    }

    private func getFirmwarePath(name: String, extension ext: String) -> String? {
        if useBundledQEMU {
            if let fileURL = Bundle.main.url(forResource: name, withExtension: ext) {
                return fileURL.path
            }
            return nil
        } else {
            let path = "/opt/homebrew/share/qemu/\(name).\(ext)"
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }
    }
    
    private func appendLog(text: String, to folderPath: String?) {
        guard let folder = folderPath, let data = text.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: folder).appendingPathComponent("qemu.log")
        
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                try? handle.seekToEnd()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
    
    // MARK: - VM Operations
    func addNewVM(osType: OSType) {
        let nameAlert = NSAlert()
        nameAlert.messageText = "Tên máy ảo mới".localized()
        nameAlert.informativeText = "Nhập tên để tạo thư mục riêng cho máy ảo này.".localized()
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameAlert.accessoryView = nameField
        nameAlert.addButton(withTitle: "Tiếp tục".localized())
        nameAlert.addButton(withTitle: "Hủy".localized())
        guard nameAlert.runModal() == .alertFirstButtonReturn, !nameField.stringValue.isEmpty else { return }
        
        let vmName = nameField.stringValue
        
        let sourcePanel = NSOpenPanel()
        sourcePanel.message = "Chọn file ISO hoặc ổ đĩa gốc".localized()
        sourcePanel.canChooseFiles = true
        guard sourcePanel.runModal() == .OK, let sourceURL = sourcePanel.url else { return }
        
        let destPanel = NSOpenPanel()
        destPanel.message = "Chọn nơi lưu thư mục máy ảo".localized()
        destPanel.canChooseDirectories = true
        destPanel.canCreateDirectories = true
        guard destPanel.runModal() == .OK, let parentURL = destPanel.url else { return }
        
        let vmFolderURL = parentURL.appendingPathComponent(vmName)
        
        let configAlert = NSAlert()
        configAlert.messageText = String(format: "Cấu hình phần cứng cho %@".localized(), vmName)
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 350, height: 230))
        stack.orientation = .vertical
        stack.spacing = 8
        
        let cpuField = NSTextField(string: "2")
        let ramField = NSTextField(string: "2048")
        let diskField = NSTextField(string: "15360")
        let archPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 350, height: 25))
        archPopup.addItems(withTitles: VMArchitecture.allCases.map { $0.rawValue })
        if osType == .windows { archPopup.selectItem(at: 0) }
        
        stack.addArrangedSubview(NSTextField(labelWithString: "Kiến trúc CPU:".localized()))
        stack.addArrangedSubview(archPopup)
        stack.addArrangedSubview(NSTextField(labelWithString: "CPU (Cores):".localized()))
        stack.addArrangedSubview(cpuField)
        stack.addArrangedSubview(NSTextField(labelWithString: "RAM (MB):".localized()))
        stack.addArrangedSubview(ramField)
        stack.addArrangedSubview(NSTextField(labelWithString: "Tạo ổ đĩa mới (MB) [0 để dùng đĩa gốc]:".localized()))
        stack.addArrangedSubview(diskField)
        
        for view in [cpuField, ramField, diskField, archPopup] {
            view.widthAnchor.constraint(equalToConstant: 350).isActive = true
        }
        
        configAlert.accessoryView = stack
        configAlert.addButton(withTitle: "Tạo VM".localized())
        configAlert.addButton(withTitle: "Hủy".localized())
        guard configAlert.runModal() == .alertFirstButtonReturn else { return }
        
        let cpuCount = Int(cpuField.stringValue) ?? 2
        let ramMB = UInt64(ramField.stringValue) ?? 2048
        let diskMB = Int(diskField.stringValue) ?? 0
        let selectedArch = VMArchitecture.allCases[archPopup.indexOfSelectedItem]
        
        do {
            try FileManager.default.createDirectory(at: vmFolderURL, withIntermediateDirectories: true)
        } catch {
            let err = NSAlert()
            err.messageText = String(format: "Lỗi tạo thư mục: %@".localized(), error.localizedDescription)
            err.runModal()
            return
        }
        
        var newVM = UniversalVMConfig(
            name: vmName,
            osType: osType,
            architecture: selectedArch,
            diskPath: "",
            ramMB: ramMB,
            cpuCount: cpuCount
        )
        newVM.vmFolderPath = vmFolderURL.path
        
        let ext = sourceURL.pathExtension.lowercased()
        let newDiskPath = vmFolderURL.appendingPathComponent("disk.raw").path
        
        if diskMB > 0 {
            if ext == "iso" { newVM.isoPath = sourceURL.path }
            self.isConverting = true
            self.conversionLabel = "Đang tạo đĩa...".localized()
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.createBlankDisk(path: newDiskPath, sizeMB: diskMB)
                DispatchQueue.main.async {
                    self.isConverting = false
                    newVM.diskPath = newDiskPath
                    self.vms.append(newVM)
                }
            }
        } else {
            self.isConverting = true
            self.conversionLabel = "Đang copy đĩa...".localized()
            
            DispatchQueue.global(qos: .userInitiated).async {
                try? FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: newDiskPath))
                DispatchQueue.main.async {
                    self.isConverting = false
                    newVM.diskPath = newDiskPath
                    self.vms.append(newVM)
                }
            }
        }
    }
    
    func updateVM(vm: UniversalVMConfig) {
        if let idx = vms.firstIndex(where: { $0.id == vm.id }) {
            vms[idx] = vm
        }
    }
    
    func deleteVM(vm: UniversalVMConfig, deleteFiles: Bool) {
        if vm.isRunning { stopVM(vm: vm) }
        
        if deleteFiles, let folder = vm.vmFolderPath {
            try? FileManager.default.removeItem(atPath: folder)
        }
        
        DispatchQueue.main.async {
            self.vms.removeAll { $0.id == vm.id }
        }
    }

    private func createBlankDisk(path: String, sizeMB: Int) {
        let process = Process()
        guard let qemuImg = getQEMUBinaryPath(name: "qemu-img") else { return }
        
        process.executableURL = qemuImg
        process.arguments = ["create", "-f", "raw", path, "\(sizeMB)M"]
        try? process.run()
        process.waitUntilExit()
    }
    
    func startVM(vm: UniversalVMConfig) {
        let process = Process()
        let isARM = (vm.architecture == .arm64)
        let qemuArch = isARM ? "qemu-system-aarch64" : "qemu-system-x86_64"
        
        guard let qemuURL = getQEMUBinaryPath(name: qemuArch) else {
            let alert = NSAlert()
            alert.messageText = "Lỗi đường dẫn QEMU".localized()
            alert.runModal()
            return
        }
        
        process.executableURL = qemuURL
        
        var args: [String] = [
            "-m", "\(vm.ramMB)",
            "-smp", "\(vm.cpuCount)",
            "-boot", "menu=on,order=dc",
            "-display", "cocoa,show-cursor=on,zoom-to-fit=on"
        ]
        
        // =========================================
        // CHỈ ĐỊNH THƯ MỤC BIOS CHO QEMU
        // =========================================
        if useBundledQEMU {
            if let biosURL = Bundle.main.url(forResource: "bios", withExtension: nil) {
                args.append(contentsOf: ["-L", biosURL.path])
            } else if let resourcePath = Bundle.main.resourcePath {
                args.append(contentsOf: ["-L", resourcePath])
            }
        }
        
        // =========================================
        // TỐI ƯU Ổ ĐĨA
        // =========================================
        let driveIf = isARM ? "virtio" : "ide"
        args.append(contentsOf: ["-drive", "file=\(vm.diskPath),format=raw,if=\(driveIf)"])
        
        if let iso = vm.isoPath, !iso.isEmpty {
            args.append(contentsOf: ["-cdrom", iso])
        }
        
        if isARM {
            let biosPath = getFirmwarePath(name: "edk2-aarch64-code", extension: "fd") ?? ""
            args.append(contentsOf: [
                "-device", "virtio-gpu-pci,xres=\(vm.width),yres=\(vm.height)",
                "-device", "qemu-xhci",
                "-device", "usb-kbd",
                "-device", "usb-tablet",
                "-netdev", "user,id=net0",
                "-device", "virtio-net-pci,netdev=net0,romfile=",
                "-M", "virt",
                "-cpu", "host",
                "-accel", "hvf",
                "-bios", biosPath
            ])
        } else {
            args.append(contentsOf: [
                "-M", "q35",
                "-cpu", "qemu64",
                "-vga", "std",
                "-device", "qemu-xhci",
                "-device", "usb-kbd",
                "-device", "usb-tablet",
                "-netdev", "user,id=net0",
                "-device", "e1000,netdev=net0,romfile=" // Driver ethernet
            ])
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let startTime = formatter.string(from: Date())
        
        appendLog(text: "\n\n========================================\n", to: vm.vmFolderPath)
        appendLog(text: "[START] VM START AT: \(startTime)\n", to: vm.vmFolderPath)
        appendLog(text: "[CMD] \(qemuArch) \(args.joined(separator: " "))\n", to: vm.vmFolderPath)
        appendLog(text: "========================================\n", to: vm.vmFolderPath)
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                self?.appendLog(text: output, to: vm.vmFolderPath)
            }
        }
        
        do {
            try process.run()
            activeProcesses[vm.id] = process
            
            DispatchQueue.main.async {
                if let idx = self.vms.firstIndex(where: { $0.id == vm.id }) {
                    self.vms[idx].isRunning = true
                }
            }
            
            process.terminationHandler = { [weak self] _ in
                pipe.fileHandleForReading.readabilityHandler = nil
                let stopTime = formatter.string(from: Date())
                self?.appendLog(text: "\n[STOP] VM STOPED AT: \(stopTime)\n", to: vm.vmFolderPath)
                
                DispatchQueue.main.async {
                    self?.activeProcesses.removeValue(forKey: vm.id)
                    if let idx = self?.vms.firstIndex(where: { $0.id == vm.id }) {
                        self?.vms[idx].isRunning = false
                    }
                }
            }
        } catch {
            appendLog(text: "[CRITICAL ERROR] QEMU Launch Failed: \(error.localizedDescription)\n", to: vm.vmFolderPath)
        }
    }
    
    func stopVM(vm: UniversalVMConfig) {
        if let process = activeProcesses[vm.id] {
            process.terminate()
            activeProcesses.removeValue(forKey: vm.id)
            if let idx = self.vms.firstIndex(where: { $0.id == vm.id }) {
                self.vms[idx].isRunning = false
            }
        }
    }
}

extension String {
    func localized() -> String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "vi"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
}
