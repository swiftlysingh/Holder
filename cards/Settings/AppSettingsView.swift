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
                HStack(alignment: .center){
                    Text("Timeout (in seconds)")
                    Spacer()
                    TextField("", value: UserSettings.shared.$authTimeout, format: .number)
                        .keyboardType(.numberPad)
                        .fixedSize()
                }
                VStack(alignment: .leading){
                    Text("Number of card digits visible on home (Restart Required)")
                    Slider(value: UserSettings.shared.$showNumber, in: 1...10,step: 1) {
                        Text("Steps")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel:  {
                        Text("10")
                    }
                }
            } header: {
                Text("App Settings")
            }
        )
    }
}
