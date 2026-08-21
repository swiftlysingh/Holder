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
    @EnvironmentObject private var authenticationSession: AuthenticationSession
    @AppStorage("isAuthEnabled") private var isVaultLockEnabled = true
    @State private var showsTipJar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Require Authentication for Vault", isOn: vaultLockBinding)
            Text("Holder asks on launch and when you return after more than 60 seconds. Security codes always need a recent authentication.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private var vaultLockBinding: Binding<Bool> {
        Binding(
            get: { isVaultLockEnabled },
            set: { newValue in
                if newValue {
                    isVaultLockEnabled = true
                    authenticationSession.vaultLockSettingChanged(isEnabled: true)
                } else {
                    authenticationSession.authenticateForSensitiveAccess(
                        reason: "Authenticate to turn off Holder's vault lock."
                    ) { success in
                        guard success else { return }
                        isVaultLockEnabled = false
                        authenticationSession.vaultLockSettingChanged(isEnabled: false)
                    }
                }
            }
        )
    }
}
