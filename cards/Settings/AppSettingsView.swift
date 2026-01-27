//
//  AppSettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Toggle("Toggle Biometrics", isOn: $settings.isAuthEnabled)
        #if os(macOS)
        Stepper("Timeout: \(settings.authTimeout) seconds",
                value: $settings.authTimeout, in: 1...120)
        #else
        HStack(alignment: .center) {
            Text("Timeout (in seconds)")
            Spacer()
            TextField("", value: $settings.authTimeout, format: .number)
                .keyboardType(.numberPad)
                .fixedSize()
        }
        #endif
        VStack(alignment: .leading) {
            Text("Number of card digits visible on home (Restart Required)")
            Slider(value: $settings.showNumber, in: 1...10, step: 1) {
                Text("Steps")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("10")
            }
        }
        #if os(macOS)
        Toggle("Keep in Menu Bar", isOn: $settings.keepInMenuBar)
        #endif
    }
}
