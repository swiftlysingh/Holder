//
//  SettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct AppSettingsView: View {
    var body: AnyView? {
        AnyView (
            Section {
                Toggle("Toggle Biometrics", isOn: UserSettings.shared.$isAuthEnabled)
                    .accessibilityLabel("Enable biometric authentication")
                    .accessibilityHint("Double tap to enable or disable biometric authentication for app security")
                    .accessibilityIdentifier("toggleBiometrics")
                    .focusable(true)
                HStack(alignment: .center){
                    Text("Timeout (in seconds)")
                        .accessibilityLabel("Authentication timeout in seconds")
                        .accessibilityIdentifier("timeoutLabel")
                    Spacer()
                    TextField("", value: UserSettings.shared.$authTimeout, format: .number)
                        .keyboardType(.numberPad)
                        .fixedSize()
                        .accessibilityLabel("Timeout value")
                        .accessibilityHint("Enter the number of seconds before authentication times out")
                        .accessibilityIdentifier("timeoutTextField")
                        .focusable(true)
                }
                .accessibilityElement(children: .combine)
                VStack(alignment: .leading){
                    Text("Number of card digits visible on home (Restart Required)")
                        .accessibilityLabel("Number of card digits visible on home. Restart required.")
                        .accessibilityIdentifier("cardDigitsLabel")
                    Slider(value: UserSettings.shared.$showNumber, in: 1...10,step: 1) {
                        Text("Steps")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel:  {
                        Text("10")
                    }
                    .accessibilityLabel("Number of visible card digits")
                    .accessibilityHint("Adjust to set how many card digits are visible on the home screen. Restart required.")
                    .accessibilityIdentifier("cardDigitsSlider")
                    .focusable(true)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("App Settings")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("appSettingsHeader")
            }
        )
    }
}
