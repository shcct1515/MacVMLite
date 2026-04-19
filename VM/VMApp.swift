//
//  VMApp.swift
//  VM
//
//  Created by Nguyễn Vinh Hiển on 17/4/26.
//

import SwiftUI

@main
struct VMApp: App {
    @AppStorage("appLanguage") private var appLanguage: String = "vi"
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, .init(identifier: appLanguage))
        }
    }
}
