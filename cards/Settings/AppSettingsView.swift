//
//  AppSettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @AppStorage("isAuthEnabled") private var isAuthEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Require Authentication", isOn: $isAuthEnabled)
            Text("Use Touch ID, Face ID, or your device password before showing card details.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        #if os(macOS)
        Stepper("Lock after: \(settings.authTimeout) seconds",
                value: $settings.authTimeout, in: 1...120)
            .disabled(!isAuthEnabled)
        #else
        HStack(alignment: .center) {
            Text("Lock after (seconds)")
            Spacer()
            TextField("", value: $settings.authTimeout, format: .number)
                .keyboardType(.numberPad)
                .fixedSize()
        }
        .disabled(!isAuthEnabled)
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
