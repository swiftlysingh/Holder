////
////  SettingsView.swift
////  credit-card
////
////  Created by Pushpinder Pal Singh on 08/12/23.
////
//
//import SwiftUI
//
//struct SettingsView: View {
//
//	var model = SettingsViewModel()
//
//	var body: some View {
//			Form {
//				Toggle("Biometrics Enabled", isOn: UserSettings.shared.$isAuthEnabled)
//				VStack(alignment: .trailing){
//					Text("Time Before You Need to Reauth In Again (in seconds)")
//						TextField("Sup", value: UserSettings.shared.$authTimeout, formatter: NumberFormatter())
//							.keyboardType(.numberPad)
//				}
//				VStack(alignment: .leading){
//					Text("Visible digits on homepage")
//
//					Slider(value: UserSettings.shared.$showNumber, in: 1...10,step: 1)
//					{
//						Text("Steps")
//					}
//
//					minimumValueLabel: {
//						Text("1")
//					}
//					maximumValueLabel:  {
//						Text("10")
//
//					}
//					Text("You may need to restart the app when updating this setting")
//						.font(.caption)
//				}
//				Section{
//					LabeledContent("App Version", value: model.appVersion)
//					Link("Twitter @swiftlysingh", destination: URL(string: "https://twitter.com/swiftlysingh")!)
//                    Link("Look at the source code", destination: URL(string: "https://github.com/swiftlysingh/holder/")!)
//					Button("Rate the App") {
//                        UserSettings.shared.requestReview()
//					}
//				}
//			header: {
//				Text("About")
//			}
//
//			}
//			.navigationTitle("Settings")
//		}
//}
//
//#Preview {
//    SettingsView()
//}
