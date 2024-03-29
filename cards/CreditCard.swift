//
//  credit_cardApp.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import TipKit
import WhatsNewKit

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
					TelemetryDeck.shared.appDidFinshLaunching()
				}
				.environment(
					\.whatsNew,
					 WhatsNewEnvironment(
						// Specify in which way the presented WhatsNew Versions are stored.
						// In default the `UserDefaultsWhatsNewVersionStore` is used.
						versionStore: UserDefaultsWhatsNewVersionStore(),
						// Pass a `WhatsNewCollectionProvider` or an array of WhatsNew instances
						whatsNewCollection: self
					 )
				)

        }
    }
}

extension CreditCard: WhatsNewCollectionProvider {

	/// Declare your WhatsNew instances per version
	var whatsNewCollection: WhatsNewCollection {
		return [ WhatsNew(
			version: "1.2",
			title: "Discover What's New in Holder!",
			features: [
				WhatsNew.Feature(
					image: .init(systemName: "cloud"),
					title: "iCloud Sync Is Here!",
					subtitle: "Effortlessly keep your cards in sync across all devices."
				),
				WhatsNew.Feature(
					image: .init(systemName: "ipad.sizes"),
					title: "Optimized for iPad",
					subtitle: "Enjoy a seamless, multitasking-friendly UI, now with split view."
				),
				WhatsNew.Feature(
					image: .init(systemName: "ant.fill"),
					title: "Bug Squashing Party 🐜🔨",
					subtitle: "We threw a party for bugs, and none made it out alive. Enjoy the smoother experience!"
				)
			],
			primaryAction: WhatsNew.PrimaryAction(
				title: "Dive In 🚀",
				backgroundColor: .accentColor,
				foregroundColor: .white,
				hapticFeedback: .notification(.success),
				onDismiss: {
					print("Ready to explore the new features!")
				}
			)
		),
			WhatsNew(
				version: "1.1",
				title: "Discover What's New in Holder!",
				features: [
					WhatsNew.Feature(
						image: .init(systemName: "camera.on.rectangle"),
						title: "Snap & Add Cards 📸",
						subtitle: "Adding your cards is now a snap away! Just point your camera, and voilà, securely stored."
					),
					WhatsNew.Feature(
						image: .init(systemName: "star.fill"),
						title: "Rate Us With a Tap 💫",
						subtitle: "Loving Holder? Tap to rate us! Your feedback brings smiles and helps us grow."
					),
					WhatsNew.Feature(
						image: .init(systemName: "ant.fill"),
						title: "Bug Squashing Party 🐜🔨",
						subtitle: "We threw a party for bugs, and none made it out alive. Enjoy the smoother experience!"
					)
				],
				primaryAction: WhatsNew.PrimaryAction(
					title: "Dive In 🚀",
					backgroundColor: .accentColor,
					foregroundColor: .white,
					hapticFeedback: .notification(.success),
					onDismiss: {
						print("Ready to explore the new features!")
					}
				)
			)
		]

	}

}
