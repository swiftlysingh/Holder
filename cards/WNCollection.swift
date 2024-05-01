//
//  WNCollection.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 01/05/24.
//

import Foundation
import WhatsNewKit

struct WNCollection: WhatsNewCollectionProvider {
    
    var primaryAction: WhatsNew.PrimaryAction {
        WhatsNew.PrimaryAction(
            title: "Dive In 🚀",
            backgroundColor: .accentColor,
            foregroundColor: .white,
            hapticFeedback: .notification(.success),
            onDismiss: {
                print("Ready to explore the new features!")
            }
        )
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
