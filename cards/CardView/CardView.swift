//
//  CardView.swift
//  credit-card
//
//  Created by Pushpinder Pal Singh on 09/12/23.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

struct CardView: View {
	
	@ObservedObject var model: CardViewModel
	@Environment(\.scenePhase) var scenePhase

	var body: some View {
		getCardListView()
			.onAppear {
				model.authenticateUser()
			}
	}

	#if os(iOS)
	fileprivate func itemView(heading: String, value: Binding<String>, _ type: UIKeyboardType) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if !model.isAuthenticated {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			} else {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.keyboardType(type)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
							UserSettings.shared.requestReview()
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
			}
		}
		.if(!model.isEditing, transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#else
	fileprivate func itemView(heading: String, value: Binding<String>) -> some View {
		return HStack {
			Text(heading)
				.bold()
			Spacer()
			if !model.isAuthenticated {
				SecureField("", text: value)
					.multilineTextAlignment(.trailing)
			} else {
				TextField("", text: value)
					.multilineTextAlignment(.trailing)
					.disabled(!model.isEditing)
					.foregroundColor(model.isEditing ? .blue : .accentColor)
					.contextMenu(menuItems: {
						Button(action: {
							model.copyAction(with: value.wrappedValue)
							UserSettings.shared.requestReview()
						}) {
							Text("Copy to clipboard")
							Image(systemName: "doc.on.doc")
						}
					})
			}
		}
		.if(!model.isEditing, transform: { view in
			view.onTapGesture(count: 2, perform: {
				model.copyAction(with: value.wrappedValue)
			})
		})
	}
	#endif

	fileprivate func getCardListView() -> some View {
		let tip = DoubleTapTip()

		return List {
			Section {
				#if os(iOS)
				let fields: [(String, Binding<String>, UIKeyboardType)] = [
					("Name", $model.card.name, .alphabet),
					("Number", $model.card.number, .numbersAndPunctuation),
					("Expiration", $model.card.expiration, .numberPad),
					("Security Code", $model.card.cvv, .numberPad),
					("Description", $model.card.description, .alphabet)
				]

				ForEach(fields, id: \.0) { heading, value, keyboardType in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(heading: heading, value: value, keyboardType)

						if heading == "Number" && !model.isEditing {
							view.popoverTip(tip, arrowEdge: .top)
						} else if heading == "Expiration" {
							view.onChange(of: model.card.expiration) { _, newValue in
								if newValue.count == 2 && !newValue.contains("/") {
									model.card.expiration = newValue + "/"
								} else if newValue.count > 5 {
									model.card.expiration = String(newValue.prefix(5))
								}
							}
						} else {
							view
						}
					}
				}
				#else
				let fields: [(String, Binding<String>)] = [
					("Name", $model.card.name),
					("Number", $model.card.number),
					("Expiration", $model.card.expiration),
					("Security Code", $model.card.cvv),
					("Description", $model.card.description)
				]

				ForEach(fields, id: \.0) { heading, value in
					if !value.wrappedValue.isEmpty || model.isEditing {
						let view = itemView(heading: heading, value: value)

						if heading == "Number" && !model.isEditing {
							view.popoverTip(tip, arrowEdge: .top)
						} else if heading == "Expiration" {
							view.onChange(of: model.card.expiration) { _, newValue in
								if newValue.count == 2 && !newValue.contains("/") {
									model.card.expiration = newValue + "/"
								} else if newValue.count > 5 {
									model.card.expiration = String(newValue.prefix(5))
								}
							}
						} else {
							view
						}
					}
				}
				#endif

				Group {
				  if model.card.type != .otherCard {
					Picker("Card Network", selection: $model.card.network) {
					  ForEach(CardNetwork.allCases) { pref in
						Text(pref.rawValue)
					  }
					}

					.disabled(!model.isEditing)
					.bold()
				  }
					Picker("Card Type", selection: $model.card.type) {
						ForEach(CardType.allCases) { pref in
							Text(pref.rawValue)
						}
					}
					.disabled(!model.isEditing)
					.bold()
				}
			}

			if let image = model.cardImage, model.card.type == .otherCard {
				Section {
					#if os(iOS)
					Image(uiImage: image)
						.resizable()
						.scaledToFit()
						.if(!model.isAuthenticated, transform: { view in
							view.blur(radius: 10, opaque: true)
						})
					#else
					Image(nsImage: image)
						.resizable()
						.scaledToFit()
						.if(!model.isAuthenticated, transform: { view in
							view.blur(radius: 10, opaque: true)
						})
					#endif
				}
			}

			#if os(iOS)
			if model.isEditing && model.card.type == .otherCard {
				Section {
					PhotosPicker(selection: $model.selectedItem, matching: .images) {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(model.cardImage == nil ? "Add Card Image" : "Change Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
					.onChange(of: model.selectedItem) {
						Task {
							if let data = try? await model.selectedItem?.loadTransferable(type: Data.self) {
								if let uiImage = UIImage(data: data) {
									model.cardImage = uiImage
									print(ICloudDataManager.shared.saveImage(uiImage, for: model.card.id))
								} else {
									print("Failed")
								}
							}
						}
					}

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.cardImage = nil
							ICloudDataManager.shared.deleteImage(for: model.card.id)
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
					}
				}
			}
			#else
			if model.isEditing && model.card.type == .otherCard {
				Section {
					Button {
						selectImageFile()
					} label: {
						VStack(alignment: .leading) {
							HStack {
								Image(systemName: "photo")
								Text(model.cardImage == nil ? "Add Card Image" : "Change Card Image")
							}
							.padding(.bottom)

							Text("Images are stored in iCloud storage instead of more secure Keychain, please be mindful while adding sensitive images")
								.font(.footnote)
								.foregroundStyle(.gray)
						}
					}
					.buttonStyle(.plain)

					if model.cardImage != nil {
						Button(role: .destructive) {
							model.cardImage = nil
							ICloudDataManager.shared.deleteImage(for: model.card.id)
						} label: {
							HStack {
								Image(systemName: "trash")
								Text("Remove Image")
							}
						}
					}
				}
			}
			#endif
		}
		.toolbar {
			ShareLink(item: model.card.toShareString()) {
				Label("Click to share", systemImage: "square.and.arrow.up")
			}
			Button(action: {
				model.isEditing.toggle()
				// if user is not editing, then he is done editing when button press
				if !$model.isEditing.wrappedValue && (model.card.type == .otherCard || !model.card.number.isEmpty){
					model.addUpdateCard(model.card)
				}
			}) {
				Text(model.isEditing ? "Done" : "Edit")
			}
		}
		.disabled(!$model.isAuthenticated.wrappedValue)
		#if os(iOS)
		.toolbar {
			if model.card.number.isEmpty {
				ToolbarItem(placement: .topBarLeading) {
					Button(action: {
						model.isShowingScanner = true
					}, label: {
						Image(systemName: "camera.on.rectangle")
					})
					.if(!model.isAddNewFlow, transform: { view in
						view.hidden()
					})
					.fullScreenCover(isPresented: $model.isShowingScanner) {
						SharkCardScanViewRepresentable(
							noPermissionAction: {
								print("Error No Permission")
							},
							successHandler: { response in
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
									model.card.number = response.number
									model.card.name = response.holder ?? ""
									model.card.expiration = response.expiry ?? ""
									model.isShowingScanner = false
									print(response.number, response.holder as Any, response.expiry as Any)
								}
							}
						)
					}
				}
			}
		}
		#endif
		.onChange(of: scenePhase) {
			if scenePhase == .background && UserSettings.shared.isAuthEnabled {
				DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(UserSettings.shared.authTimeout)) {
					if scenePhase == .background {
						self.model.$isAuthenticated.wrappedValue = false
					}
				}
			}
		}
		.onDisappear(perform: {
			model.$isAuthenticated.wrappedValue = false
		})
	}

	#if os(macOS)
	private func selectImageFile() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.image]
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.title = "Select Card Image"

		if panel.runModal() == .OK, let url = panel.url {
			if let image = NSImage(contentsOf: url) {
				model.cardImage = image
				_ = ICloudDataManager.shared.saveImage(image, for: model.card.id)
			}
		}
	}
	#endif
}
