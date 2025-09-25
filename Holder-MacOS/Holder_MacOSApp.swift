//
//  Holder_MacOSApp.swift
//  Holder-MacOS
//
//  Created by Pushpinder on 9/25/25.
//

import SwiftUI

@main
struct Holder_MacOSApp: App {
    var body: some Scene {
        MenuBarExtra("My Status App", systemImage: "creditcard.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.automatic)
    }
}
