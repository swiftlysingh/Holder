//
//  ContentView.swift
//  Holder-MacOS
//
//  Created by Pushpinder on 9/25/25.
//

import SwiftUI

struct ContentView: View {
    @State private var statusText = "Loading..."
    
    var body: some View {
        VStack(spacing: 6) {
            Text(statusText)
                .font(.system(.caption, design: .monospaced))
            
            Button("Open App") { openMainApp() }
                .controlSize(.mini)
        }
        .padding(8)
        .frame(width: 120, height: 60)
    }
    
    private func openMainApp() {
//        // Launch your main Catalyst app
//        let url = URL(string: "your-app-scheme://")! // Custom URL scheme
//        NSWorkspace.shared.open(url)
        
        // Or launch by bundle ID
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.swiftlysingh.holder",
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
    }
}

#Preview {
    ContentView()
}
