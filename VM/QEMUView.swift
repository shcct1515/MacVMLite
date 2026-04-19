//
//  QEMUView.swift
//  VM
//
//  Created by Nguyễn Vinh Hiển on 18/4/26.
//
import Foundation
import SwiftUI
import Combine

enum QEMUStatus {
    case checking
    case installed(version: String)
    case notInstalled
    case processing(action: String, percent: String)
    case error(String)
}

class QEMUManager: ObservableObject {
    @Published var status: QEMUStatus = .checking
    
    private let brewPath = "/opt/homebrew/bin/brew"
    private let qemuImgPath = "/opt/homebrew/bin/qemu-img"
    
    init() { checkStatus() }
    
    func checkStatus() {
        self.status = .checking
        DispatchQueue.global(qos: .background).async {
            let (output, code) = self.runShellSync("\(self.qemuImgPath) --version")
            DispatchQueue.main.async {
                if code == 0 {
                    let firstLine = output.components(separatedBy: "\n").first ?? "Đã cài đặt"
                    self.status = .installed(version: firstLine)
                } else {
                    self.status = .notInstalled
                }
            }
        }
    }
    
    func installQEMU() {
        self.status = .processing(action: "Đang cài đặt...", percent: "0%")
        var currentPercent = "0%"
        
        self.runShellAsync("\(self.brewPath) install qemu") { output in
            if let p = self.extractPercent(output) { currentPercent = p }
            self.status = .processing(action: "Đang tải QEMU...", percent: currentPercent)
        } completion: { code in
            code == 0 ? self.checkStatus() : (self.status = .error("Lỗi cài đặt."))
        }
    }
    
    func uninstallQEMU() {
        self.status = .processing(action: "Đang gỡ sạch...", percent: "Đang xóa")
        self.runShellAsync("\(self.brewPath) uninstall --force qemu && \(self.brewPath) autoremove") { _ in
        } completion: { _ in
            self.checkStatus()
        }
    }
    
    func reinstallQEMU() {
        self.status = .processing(action: "Đang cài lại...", percent: "0%")
        var currentPercent = "0%"
        self.runShellAsync("\(self.brewPath) reinstall qemu") { output in
            if let p = self.extractPercent(output) { currentPercent = p }
            self.status = .processing(action: "Đang tải lại...", percent: currentPercent)
        } completion: { _ in
            self.checkStatus()
        }
    }
    
    private func extractPercent(_ text: String) -> String? {
        if let range = text.range(of: #"\d{1,3}(\.\d+)?%"#, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
    
    private func runShellSync(_ command: String) -> (String, Int32) {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        task.arguments = ["-c", command]; task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        do {
            try task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
        } catch { return ("", -1) }
    }
    
    private func runShellAsync(_ command: String, progress: @escaping (String) -> Void, completion: @escaping (Int32) -> Void) {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        task.arguments = ["-c", command]; task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { progress(str) }
            }
        }
        task.terminationHandler = { process in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { completion(process.terminationStatus) }
        }
        try? task.run()
    }
}

struct QEMUStatusView: View {
    @StateObject private var qemuManager = QEMUManager()
    
    // Đọc trạng thái người dùng muốn dùng loại nào
    @AppStorage("useBundledQEMU") var useBundledQEMU: Bool = true
    
    var body: some View {
        Menu {
            Section("Lựa chọn Nguồn QEMU") {
                Button(action: { useBundledQEMU = true }) {
                    HStack {
                        if useBundledQEMU { Image(systemName: "checkmark") }
                        Text("Dùng QEMU đóng gói (App Bundle)")
                    }
                }
                
                Button(action: { useBundledQEMU = false }) {
                    HStack {
                        if !useBundledQEMU { Image(systemName: "checkmark") }
                        Text("Dùng QEMU Hệ thống (Homebrew)")
                    }
                }
            }
            
            // Nếu người dùng chọn Homebrew
            if !useBundledQEMU {
                Section("Quản lý Homebrew QEMU") {
                    switch qemuManager.status {
                    case .notInstalled:
                        Button(action: { qemuManager.installQEMU() }) {
                            Label("Tải & Cài đặt QEMU", systemImage: "square.and.arrow.down")
                        }
                    case .installed(let version):
                        Text(version)
                        
                        Button(action: { qemuManager.reinstallQEMU() }) {
                            Label("Cài lại QEMU", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(role: .destructive, action: { qemuManager.uninstallQEMU() }) {
                            Label("Gỡ sạch QEMU", systemImage: "trash")
                        }
                    case .error:
                        Button(action: { qemuManager.checkStatus() }) {
                            Label("Kiểm tra lại trạng thái", systemImage: "arrow.clockwise")
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            
        } label: {
            HStack(spacing: 8) {
                iconForStatus()
                textForStatus()
                Image(systemName: "chevron.up")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(backgroundForStatus()).foregroundColor(.white)
            .cornerRadius(20).shadow(radius: 3)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .frame(minWidth: 200, alignment: .trailing)
    }
    
    // MARK: - Logic Giao Diện Nút
    @ViewBuilder private func iconForStatus() -> some View {
        if useBundledQEMU {
            Image(systemName: "shippingbox.fill")
        } else {
            switch qemuManager.status {
            case .checking, .processing: ProgressView().controlSize(.small).tint(.white)
            case .installed: Image(systemName: "checkmark.circle.fill")
            case .notInstalled: Image(systemName: "exclamationmark.triangle.fill")
            case .error: Image(systemName: "xmark.octagon.fill")
            }
        }
    }
    
    @ViewBuilder private func textForStatus() -> Text {
        if useBundledQEMU {
            return Text("QEMU: App Bundle").bold()
        } else {
            switch qemuManager.status {
            case .checking: return Text("Đang kiểm tra...")
            case .processing(let action, let percent): return Text("\(action) \(percent)")
            case .installed: return Text("QEMU: Homebrew").bold()
            case .notInstalled: return Text("QEMU: Chưa cài đặt").bold()
            case .error(let msg): return Text("Lỗi: \(msg)").bold()
            }
        }
    }
    
    private func backgroundForStatus() -> Color {
        if useBundledQEMU {
            return .blue
        } else {
            switch qemuManager.status {
            case .installed: return .green
            case .notInstalled: return .orange
            case .error: return .red
            case .checking, .processing: return .gray
            }
        }
    }
}
