//
//  TelemetryDeck.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 25/03/24.
//

import TelemetryClient


struct TelemetryDeck {

	let configuration = TelemetryManagerConfiguration(
		appID: "7546C497-F61C-4007-A7F6-16F0543702BF")

	static let shared = TelemetryDeck()

	init() {
		TelemetryManager.initialize(with: configuration)
	}
	
	func appDidFinshLaunching() {
		sendEvent(with: "applicationDidFinishLaunching", and: [String:String]())
	}

	private func sendEvent(with name : String, and data: [String:String]){
		TelemetryManager.send(name,with: data)
	}
}
