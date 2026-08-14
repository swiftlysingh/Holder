//
//  AppSettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SinghDevKit
import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    // Intentionally bypass UserSettings.shared: @AppStorage on the view invalidates
    // reliably when the toggle changes (UserSettings' @AppStorage does not publish).
    @AppStorage("isAuthEnabled") private var isAuthEnabled = true
    @State private var showsTipJar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Require Authentication", isOn: $isAuthEnabled)
            Text("Use Touch ID, Face ID, or your device passcode before showing card details. Documents always re-lock individually.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        #if os(macOS)
		Stepper("Lock after inactivity: \(settings.authTimeout) seconds",
                value: $settings.authTimeout, in: 1...120)
            .disabled(!isAuthEnabled)
        #else
        HStack(alignment: .center) {
			Text("Lock after inactivity (seconds)")
            Spacer()
            TextField("", value: $settings.authTimeout, format: .number)
                .keyboardType(.numberPad)
                .fixedSize()
                .onChange(of: settings.authTimeout) { _, newValue in
                    settings.authTimeout = min(max(newValue, 1), 120)
                }
        }
        .disabled(!isAuthEnabled)
        #endif
        VStack(alignment: .leading, spacing: 4) {
            Label("Storage & Privacy", systemImage: "lock.shield")
                .font(.headline)
            Text("Cards are protected by Keychain and may sync through iCloud Keychain when you enable it. New document photos are encrypted and stored only on this device. Legacy Other Card images may remain in iCloud until you remove them.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        #if os(macOS)
        Toggle("Keep in Menu Bar", isOn: $settings.keepInMenuBar)
        #endif
        Button {
            showsTipJar = true
        } label: {
            Label("Support Holder", systemImage: "heart.fill")
        }
        .sheet(isPresented: $showsTipJar) {
            SDKPaywallView(
                displayCloseButton: true,
                analyticsContext: SDKPaywallContext(source: "settings_support")
            )
        }
    }
}
