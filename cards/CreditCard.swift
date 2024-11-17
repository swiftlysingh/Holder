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
import OnboardingKit

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
				.showOnboardingIfNeeded(using: .prod)

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

extension OnboardingConfiguration {
	static let prod = Self.init(privacyUrlString: "",
								accentColor: .blue,
								features: [
									.init(image: Image(systemName: "lock.shield"),
										  title: "Secure Storage",
										  content: "Keep your card details safe with state-of-the-art encryption."),
									.init(image: Image(systemName: "faceid"),
										  title: "Biometric Authentication",
										  content: "Access your cards securely using Face ID or Touch ID."),
									.init(image: Image(systemName: "square.and.arrow.up"),
										  title: "Easily Shareable",
										  content: "Quickly and securely share card details with trusted contacts."),
									.init(image: Image(systemName: "hand.raised.slash"),
										  title: "Privacy First, Open Source",
										  content: "Your data stays private and secure, and the app's code is open-source for transparency.")
								]
	)
}
