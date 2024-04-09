//
//  iHausmeisterApp.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 03.04.24.
//

import os
import SwiftUI

@main
/// Starting the iHausmeister app.
struct IHausmeisterApp: App {
    var body: some Scene {
        Logger().trace("Starting app")
        return WindowGroup {
            ContentView()
        }
    }
}
