//
//  SettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct SettingsView: View {

	var model = SettingsViewModel()

	var body: some View {
		NavigationStack {
			Form {
				VStack(alignment: .leading){
					Text("Visible digits on homepage")

					Slider(value: UserSettings.shared.$showNumber, in: 1...10,step: 1)
					{
						Text("Steps")
					}

					minimumValueLabel: {
						Text("1")
					}
					maximumValueLabel:  {
						Text("10")

					}
					Text("You may need to reboot the app when updating this setting")
						.font(.caption)
				}
				Section{
					LabeledContent("App Version", value: model.appVersion)
					Link("Follow me on twitter @swiftlysingh", destination: URL(string: "https://twitter.com/swiftlysingh")!)
					Button("Rate the App") {
						model.requestReview()
					}
				}
			header: {
				Text("About")
			}

			}
			.navigationTitle("Settings")
		}
	}
}

#Preview {
    SettingsView()
}
