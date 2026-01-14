//
//  credit_cardApp.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import TipKit
import WhatsNewKit
import Analytics
import OnboardingKit

@main
struct CreditCard: App {
    /// Shared card data store for menu bar access on macOS
    @State private var cardDataStore = CardDataStore()

    private var appID: String {
        let path = Bundle.main.path(forResource: "Secrets", ofType: "plist")
        let dict = NSDictionary(contentsOfFile: path!) as? [String: AnyObject]
        return dict!["TDeck"] as! String
    }

    var body: some Scene {
        WindowGroup {
            HomeView(cardDataStore: cardDataStore)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .task {
                    await AnalyticsManager.shared.configure(with: appID)
                    await AnalyticsManager.shared.appDidFinishLaunching()
                }
                .environment(
                    \.whatsNew,
                     WhatsNewEnvironment(
                        versionStore: UserDefaultsWhatsNewVersionStore(),
                        whatsNewCollection: self
                     )
                )
                .showOnboardingIfNeeded(using: .prod)
        }
        #if os(macOS)
        menuBarScene
        #endif
    }

    #if os(macOS)
    var menuBarScene: some Scene {
        MenuBarExtra("Holder", systemImage: "creditcard.fill") {
            MenuBarView(cardStore: cardDataStore)
        }
        .menuBarExtraStyle(.window)
    }
    #endif
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


extension CreditCard: WhatsNewCollectionProvider {
  var primaryAction: WhatsNew.PrimaryAction {
	#if os(iOS)
	WhatsNew.PrimaryAction(
	  title: "Dive In 🚀",
	  backgroundColor: .accentColor,
	  foregroundColor: .white,
	  hapticFeedback: .notification(.success),
	  onDismiss: {
		print("Ready to explore the new features!")
	  }
	)
	#else
	WhatsNew.PrimaryAction(
	  title: "Dive In 🚀",
	  backgroundColor: .accentColor,
	  foregroundColor: .white,
	  onDismiss: {
		print("Ready to explore the new features!")
	  }
	)
	#endif
  }

  var title: WhatsNew.Title {
	return WhatsNew.Title(text: "Discover What's New in Holder!")
  }

  var bugFixFeature: WhatsNew.Feature {
	WhatsNew.Feature(
	  image: .init(systemName: "ant.fill"),
	  title: "Bug Squashing Party 🐜🔨",
	  subtitle: "We threw a party for bugs, and none made it out alive. Enjoy the smoother experience!"
	)
  }

  var whatsNewCollection: WhatsNewCollection {
	return [
	  WhatsNew(
		version: "1.6",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "camera.fill"),
			title: "Add & Store All Your Cards",
			subtitle: "Easily save gift cards, ID cards, and more with images for quick access!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),

	  WhatsNew(
		version: "1.5",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "gear.badge.checkmark"),
			title: "New and improved settings",
			subtitle: "Configurations are easier and beautiful than ever!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.4",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "creditcard.and.123"),
			title: "Network Images are here!",
			subtitle: "Now, it's easy to identify cards using there network!"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.3",
		title: title,
		features: [
		  WhatsNew.Feature(
			image: .init(systemName: "square.and.arrow.up.fill"),
			title: "Sharing is here",
			subtitle: "Effortlessly share your cards with friends and family"
		  ),
		  WhatsNew.Feature(
			image: .init(systemName: "ipad.sizes"),
			title: "Now Authentication is Optional",
			subtitle: "For the daring, enjoy a more smooth experience with no Authentication"
		  ),
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.2",
		title: title,
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
		  bugFixFeature
		],
		primaryAction: primaryAction
	  ),
	  WhatsNew(
		version: "1.1",
		title: title,
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
		  bugFixFeature
		],
		primaryAction: primaryAction
	  )
	]

  }
}
