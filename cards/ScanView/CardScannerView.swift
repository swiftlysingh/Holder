#if os(iOS)
import SinghDevKit
import SwiftUI
import UIKit

struct CardScannerView: View {
	var isRescan: Bool
	var onCancel: () -> Void
	var onPermissionDenied: () -> Void
	var onResult: (CardScanResult, CardScanMetrics) -> Void

	@StateObject private var model: CardScannerViewModel

	init(
		isRescan: Bool,
		onCancel: @escaping () -> Void,
		onPermissionDenied: @escaping () -> Void,
		onResult: @escaping (CardScanResult, CardScanMetrics) -> Void
	) {
		self.isRescan = isRescan
		self.onCancel = onCancel
		self.onPermissionDenied = onPermissionDenied
		self.onResult = onResult
		_model = StateObject(wrappedValue: CardScannerViewModel(isRescan: isRescan))
	}

	var body: some View {
		ZStack {
			model.engine.makeCameraView()

			VStack(spacing: 16) {
				HStack {
					Button("Cancel") {
						model.stop()
						onCancel()
					}
					.foregroundStyle(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
					.background(.black.opacity(0.45), in: Capsule())
					Spacer()
					if model.isTorchAvailable {
						Button {
							model.toggleTorch()
						} label: {
							Image(systemName: model.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
								.frame(width: 40, height: 40)
						}
						.foregroundStyle(model.isTorchOn ? Color.yellow : Color.white)
						.background(.black.opacity(0.45), in: Circle())
						.accessibilityLabel(model.isTorchOn ? "Turn flashlight off" : "Turn flashlight on")
					}
				}
				.padding()

				Spacer()

				VStack(spacing: 8) {
					if let lastFour = model.candidateLastFour, let network = model.candidateNetwork {
						Text("\(network.rawValue) •••• \(lastFour)")
							.font(.headline)
							.foregroundStyle(.white)
					}
					Text(model.guidance)
						.font(.subheadline)
						.multilineTextAlignment(.center)
						.foregroundStyle(.white)
						.padding(.horizontal, 24)
				}
				.padding(.bottom, 48)
			}
		}
		.background(Color.black)
		.sdkScreen(AppAnalyticsScreen.cardScanner)
		.alert("Scanner", isPresented: $model.showsMessage) {
			Button("OK") {
				model.stop()
				onCancel()
			}
		} message: {
			Text(model.message)
		}
		.onAppear {
			UIAccessibility.post(notification: .announcement, argument: model.guidance)
		}
		.task {
			await model.consumeUpdates(
				onPermissionDenied: onPermissionDenied,
				onResult: onResult
			)
		}
		.onDisappear {
			model.stop()
		}
		.onChange(of: model.guidance) { _, guidance in
			UIAccessibility.post(notification: .announcement, argument: guidance)
		}
	}
}

@MainActor
final class CardScannerViewModel: ObservableObject {
	@Published var guidance = "Fit the whole card in the frame"
	@Published var candidateLastFour: String?
	@Published var candidateNetwork: CardNetwork?
	@Published private(set) var isTorchOn = false
	@Published var showsMessage = false
	@Published var message = ""

	let engine: any CardScanningEngine
	private let isRescan: Bool
	private let startedAt = Date()
	private var panDetectedAt: Date?
	private var stopped = false

	init(isRescan: Bool, engine: (any CardScanningEngine)? = nil) {
		self.isRescan = isRescan
		self.engine = engine ?? CardScanningEngineFactory.make()
	}

	var isTorchAvailable: Bool {
		engine.isTorchAvailable
	}

	func toggleTorch() {
		isTorchOn = engine.setTorchEnabled(!isTorchOn)
	}

	func consumeUpdates(
		onPermissionDenied: @escaping () -> Void,
		onResult: @escaping (CardScanResult, CardScanMetrics) -> Void
	) async {
		guard !stopped else { return }

		for await update in engine.scanUpdates() {
			guard !stopped else { return }
			switch update {
			case .permissionDenied:
				stop()
				onPermissionDenied()
				return
			case .unsupported(let text), .failed(let text):
				stop()
				message = text
				showsMessage = true
				return
			case .retryableFailure(let text):
				candidateLastFour = nil
				candidateNetwork = nil
				guidance = text
			case .scanning(let text):
				guidance = text
			case .candidate(let lastFour, let network):
				if panDetectedAt == nil {
					panDetectedAt = Date()
				}
				candidateLastFour = lastFour
				candidateNetwork = network
				guidance = "Hold steady…"
			case .verified(let result):
				let metrics = metrics(for: result)
				stop()
				onResult(result, metrics)
				return
			}
		}
	}

	func stop() {
		guard !stopped else { return }
		stopped = true
		isTorchOn = false
		engine.setTorchEnabled(false)
		engine.stop()
	}

	private func metrics(for result: CardScanResult) -> CardScanMetrics {
		let completed = Int(Date().timeIntervalSince(startedAt) * 1000)
		let panMs = panDetectedAt.map { Int($0.timeIntervalSince(startedAt) * 1000) }
		return CardScanMetrics(
			engine: engine.engineID,
			timeToPANMs: panMs,
			timeToCompleteMs: completed,
			panSuccess: !result.pan.isEmpty,
			expirySuccess: result.expiry?.isEmpty == false,
			holderSuccess: result.cardholderName?.isEmpty == false,
			wasRescan: isRescan
		)
	}
}
#endif
