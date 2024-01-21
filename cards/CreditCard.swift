//
//  credit_cardApp.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import TipKit

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
        }
    }
}
