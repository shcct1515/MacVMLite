//
//  VMconfig.swift
//  VM
//
//  Created by Nguyễn Vinh Hiển on 17/4/26.
//
import Foundation

enum OSType: String, Codable, CaseIterable {
    case linux = "Linux (Ubuntu/Fedora)"
    case windows = "Windows"
}

// THÊM ENUM
enum VMArchitecture: String, Codable, CaseIterable {
    case arm64 = "ARM64 (Apple Silicon)"
    case x86_64 = "x86_64 (Intel/AMD)"
}

struct UniversalVMConfig: Codable, Identifiable {
    var id = UUID()
    var name: String
    var osType: OSType
    var architecture: VMArchitecture = .arm64
    var diskPath: String
    var isoPath: String?
    var vmFolderPath: String?
    var ramMB: UInt64
    var cpuCount: Int
    var isRunning: Bool = false
    var width: Int = 800
    var height: Int = 600
}
