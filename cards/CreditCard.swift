//
//  credit_cardApp.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import TipKit
import WhatsNewKit
import Boilerplate

@main
struct CreditCard: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
				.onAppear {
					TDeckClient.shared.appDidFinshLaunching()
				}
				.environment(
					\.whatsNew,
					 WhatsNewEnvironment(
						versionStore: UserDefaultsWhatsNewVersionStore(),
						whatsNewCollection: WNCollection()
					 )
				)
				.environment(BoilerPlate(delegate: self))

        }
    }
}

extension CreditCard: BoilerPlated {
	var appID: String {
		 let path = Bundle.main.path(forResource: "Secrets", ofType: "plist")
		let dict = NSDictionary(contentsOfFile: path!) as? [String: AnyObject]
		return dict!["TDeck"] as! String
	}
}
