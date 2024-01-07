//
//  SettingsView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI

struct SettingsView: View {

	@Bindable var model = UserSettings.shared

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
				}
				Section{
					LabeledContent("App Version", value: model.appVersion)
					Link("Follow me on twitter @swiftlysingh", destination: URL(string: "https://twitter.com/swiftlysingh")!)
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
