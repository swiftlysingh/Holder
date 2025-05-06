//
//  ContentView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 08/12/23.
//

import SwiftUI
import WhatsNewKit
import Settings

struct HomeView: View {

	@ObservedObject var model = HomeViewModel()

	var body: some View {
		NavigationSplitView {
			List(CardType.allCases, selection: $model.selectedCard){ type in
					Section(header: Text("\(type.rawValue)s")){
						ForEach(model.cardDataStore.cardsByType[type] ?? [], id: \.id) { card in
							getRowforCards(with: card)
								.accessibilityIdentifier("CardRow_\(card.id.uuidString)")
						}
						.onDelete { offsets in
							model.deleteCard(at: offsets, inSection: type)
						}
						Button("Add a new \(type.rawValue)") {
							model.showingPopover.toggle()
						}
						.accessibilityLabel(Text("Add a new \(type.rawValue) card"))
						.accessibilityHint(Text("Adds a new \(type.rawValue) card"))
						.accessibilityIdentifier("AddCardButton_\(type.rawValue)")
						.sheet(isPresented: $model.showingPopover) {
							NavigationView {
								CardView(model: CardViewModel(
									card: .init(id: UUID(),
												number: "",
												cvv: "",
												expiration: "",
												name: "",
												description: "",
												type: type
											   ),
									isEditing: true,
									addNewFlow: true,
									addUpdateCard: { card in
										model.cardDataStore.addCard(card)
										model.showingPopover = false
										model.cardDataStore.loadCards()
									})
								)
							}
						}
					}
				}
			.navigationTitle("Cards")
			.accessibilityLabel(Text("Cards"))
			.onAppear {
				model.cardDataStore.loadCards()
			}
			.toolbar{
                NavigationLink(destination: SettingsView(model: SettingsViewModel())){
					Image(systemName: "gear")
				}
				.accessibilityLabel(Text("Settings"))
				.accessibilityHint(Text("Opens settings"))
				.accessibilityIdentifier("SettingsButton")
			}
			.alert("Enable Biometrics",isPresented: model.$isFirstLaunch, actions: {
				Button("Yes", role: .cancel) { 
					UserSettings.shared.isAuthEnabled = true
				}
				.accessibilityLabel(Text("Enable biometrics"))
				.accessibilityHint(Text("Enables biometric authentication"))
				.accessibilityIdentifier("EnableBiometricsYesButton")
				Button("No", role: .destructive) { 
					UserSettings.shared.isAuthEnabled = false
				}
				.accessibilityLabel(Text("Do not enable biometrics"))
				.accessibilityHint(Text("Disables biometric authentication"))
				.accessibilityIdentifier("EnableBiometricsNoButton")
			})
		} detail: {
			if let card = model.selectedCard {
				CardView(model: CardViewModel(
								card: card,
								addUpdateCard: { card in
									model.cardDataStore.addCard(card)
								}))
			} 
			else {
				Text("Tap on a Card to view details")
					.accessibilityLabel(Text("No card selected. Tap on a card to view details."))
					.accessibilityIdentifier("NoCardSelectedText")
			}
		}
		.whatsNewSheet()
	}

	private func getRowforCards(with card: CardData) -> some View {
		NavigationLink(value: card){
			HStack{
				Image(card.network.rawValue)
					.resizable()
					.scaledToFit()
					.frame(width: 36,height: 36)
					.accessibilityLabel(Text("\(card.network.rawValue) logo"))
					.accessibilityIdentifier("CardNetworkImage_\(card.id.uuidString)")

				VStack(alignment: .leading){
					if card.description != "" {
						Text(card.description)
							.accessibilityLabel(Text(card.description))
							.accessibilityIdentifier("CardDescription_\(card.id.uuidString)")
							.minimumScaleFactor(0.8)
					} else {
						Text(card.name)
							.accessibilityLabel(Text(card.name))
							.accessibilityIdentifier("CardName_\(card.id.uuidString)")
							.minimumScaleFactor(0.8)
					}
					Text(card.number.toSecureCard())
						.accessibilityLabel(Text("Card number ending in \(card.number.suffix(4))"))
						.accessibilityIdentifier("CardNumber_\(card.id.uuidString)")
						.minimumScaleFactor(0.8)
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel(Text("\(card.description != "" ? card.description : card.name), card ending in \(card.number.suffix(4)), \(card.network.rawValue)"))
			.accessibilityHint(Text("Double tap to view card details"))
			.accessibilityIdentifier("CardRow_\(card.id.uuidString)")
		}
	}
}
