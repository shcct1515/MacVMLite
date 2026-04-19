//
//  ContentView.swift
//  VM
//
//  Created by Nguyễn Vinh Hiển on 17/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject var manager = VMManager()
    @State private var selectedVMID: UUID?
    @AppStorage("appLanguage") private var appLanguage: String = "vi"

    var body: some View {
        ZStack {
            NavigationSplitView {
                // MARK: - Sidebar
                VStack(spacing: 0) {
                    List(selection: $selectedVMID) {
                        ForEach(manager.vms) { vm in
                            NavigationLink(value: vm.id) {
                                SidebarRow(vm: vm, manager: manager, selectedVMID: $selectedVMID)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Menu {
                        ForEach(OSType.allCases, id: \.self) { os in
                            Button(os.rawValue) { manager.addNewVM(osType: os) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                            Text("Tạo máy ảo mới").font(.headline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                        .padding(12)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $appLanguage) {
                            Text("🇻🇳 Tiếng Việt").tag("vi")
                            Text("🇬🇧 English").tag("en")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: appLanguage) { newValue in
                            UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .navigationSplitViewColumnWidth(min: 280, ideal: 300)
                
            } detail: {
                // MARK: - Detail View
                if let selectedID = selectedVMID, let index = manager.vms.firstIndex(where: { $0.id == selectedID }) {
                    VMDetailView(vm: $manager.vms[index], manager: manager)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 70))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Chọn máy ảo để bắt đầu")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - Overlays
            if manager.isConverting {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    ProgressView(value: manager.conversionProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 300)
                    Text(manager.conversionLabel)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(Color.gray)
                .cornerRadius(15)
            }
        }
        .frame(minWidth: 900, minHeight: 550)
        .overlay(alignment: .bottomTrailing) {
            QEMUStatusView().padding()
        }
    }
}

// MARK: - VM Detail View
struct VMDetailView: View {
    @Binding var vm: UniversalVMConfig
    @ObservedObject var manager: VMManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Cài đặt máy ảo: \(vm.name)").font(.largeTitle).bold()
                Spacer()
                Button(action: {
                    vm.isRunning ? manager.stopVM(vm: vm) : manager.startVM(vm: vm)
                }) {
                    Label(vm.isRunning ? "Đang chạy" : "Khởi động", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isRunning ? .orange : .green)
                .controlSize(.large)
            }
            
            Divider()
            
            Form {
                Section(header: Text("Cấu hình phần cứng")) {
                    TextField("Tên hiển thị:", text: $vm.name)
                        .textFieldStyle(.roundedBorder)
                    
                    Stepper("CPU: \(vm.cpuCount) Cores", value: $vm.cpuCount, in: 1...32)
                    
                    HStack {
                        Text("RAM (MB):")
                        TextField("", value: $vm.ramMB, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Picker("Kiến trúc:", selection: $vm.architecture) {
                        ForEach(VMArchitecture.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    
                    Picker("Độ phân giải:", selection: Binding(
                        get: { "\(vm.width)x\(vm.height)" },
                        set: { newValue in
                            let parts = newValue.split(separator: "x")
                            if parts.count == 2 {
                                vm.width = Int(parts[0]) ?? 1280
                                vm.height = Int(parts[1]) ?? 720
                            }
                        }
                    )) {
                        Text("800 x 600").tag("800x600")
                        Text("1024 x 768").tag("1024x768")
                        Text("1280 x 720 (HD)").tag("1280x720")
                        Text("1440 x 900").tag("1440x900")
                        Text("1920 x 1080 (FHD)").tag("1920x1080")
                    }
                }
                .disabled(vm.isRunning)
                
                Section(header: Text("Thông tin hệ thống")) {
                    Text("Thư mục lưu trữ:").font(.caption).foregroundColor(.secondary)
                    Text(vm.vmFolderPath ?? "Chưa rõ")
                        .font(.caption2).foregroundColor(.gray)
                        .padding(.bottom, 8)
                    
                    Text("Ổ đĩa chính:").font(.caption).foregroundColor(.secondary)
                    Text(vm.diskPath)
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(30)
    }
}

// MARK: - Sidebar Row View
struct SidebarRow: View {
    var vm: UniversalVMConfig
    var manager: VMManager
    @Binding var selectedVMID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vm.name).font(.headline).lineLimit(1)
                Spacer()
                Circle().fill(vm.isRunning ? Color.green : Color.gray).frame(width: 8, height: 8)
            }
            Text(vm.architecture.rawValue).font(.caption2).foregroundColor(.secondary)
            
            HStack {
                Button(vm.isRunning ? "Dừng" : "Chạy") {
                    vm.isRunning ? manager.stopVM(vm: vm) : manager.startVM(vm: vm)
                }
                .buttonStyle(.bordered)
                .tint(vm.isRunning ? .orange : .blue)
                
                Spacer()
                
                Button(role: .destructive) { confirmDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }.controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    private func confirmDelete() {
        let alert = NSAlert()
            let msg = String(format: "Xóa máy ảo %@?".localized(), vm.name)
            alert.messageText = msg
            alert.informativeText = "Dữ liệu trong thư mục sẽ bị xóa vĩnh viễn nếu bạn chọn 'Xóa sạch file'.".localized()
            
            alert.addButton(withTitle: "Xóa sạch file".localized())
            alert.addButton(withTitle: "Chỉ xóa khỏi danh sách".localized())
            alert.addButton(withTitle: "Hủy".localized())
        let res = alert.runModal()
        
        if res == .alertFirstButtonReturn {
            manager.deleteVM(vm: vm, deleteFiles: true)
            if selectedVMID == vm.id { selectedVMID = nil }
        } else if res == .alertSecondButtonReturn {
            manager.deleteVM(vm: vm, deleteFiles: false)
            if selectedVMID == vm.id { selectedVMID = nil }
        }
    }
}
