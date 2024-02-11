//
//  SharkCardScanViewRepresentable.swift
//  cards
//
//  Created by Pushpinder Pal Singh on 31/01/24.
//
#if os(iOS)
import SharkCardScan
import SwiftUI

struct SharkCardScanViewRepresentable: UIViewControllerRepresentable {
	var noPermissionAction: () -> Void
	var successHandler: (CardScannerResponse) -> Void

	func makeUIViewController(context: Context) -> SharkCardScanViewController {
		let viewModel = CardScanViewModel(noPermissionAction: noPermissionAction, successHandler: successHandler)
		return SharkCardScanViewController(viewModel: viewModel, styling: CardScanViewStyle())
	}

	func updateUIViewController(_ uiViewController: SharkCardScanViewController, context: Context) {
	}
}
#endif
