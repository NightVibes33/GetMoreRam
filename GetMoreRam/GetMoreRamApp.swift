//
//  GetMoreRamApp.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/14.
//

import SwiftUI

@main
struct GetMoreRamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-UITestScreenshot") {
                        return
                    }
                    #endif
                    await DataManager.shared.model.restoreSavedSession()
                }
        }
    }
}
