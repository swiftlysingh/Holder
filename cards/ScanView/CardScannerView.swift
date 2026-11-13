#if os(iOS)
import SinghDevKit
import SwiftUI
import UIKit

struct CardScannerView: View {
	var isRescan: Bool
	var attemptNumber: Int
	var onCancel: () -> Void
	var onPermissionDenied: () -> Void
	var onManualEntry: (() -> Void)?
	var onEnded: (CardScanEndMetrics) -> Void
	var onRetryableFailure: (CardScanRetryMetrics) -> Void
	var onResult: (CardScanResult, CardScanMetrics) -> Void

	@Environment(\.scenePhase) private var scenePhase
	@StateObject private var model: CardScannerViewModel

	init(
		isRescan: Bool,
		attemptNumber: Int = 1,
		onCancel: @escaping () -> Void,
		onPermissionDenied: @escaping () -> Void,
		onManualEntry: (() -> Void)? = nil,
		onEnded: @escaping (CardScanEndMetrics) -> Void = { _ in },
		onRetryableFailure: @escaping (CardScanRetryMetrics) -> Void = { _ in },
		onResult: @escaping (CardScanResult, CardScanMetrics) -> Void
	) {
		self.isRescan = isRescan
		self.attemptNumber = attemptNumber
		self.onCancel = onCancel
		self.onPermissionDenied = onPermissionDenied
		self.onManualEntry = onManualEntry
		self.onEnded = onEnded
		self.onRetryableFailure = onRetryableFailure
		self.onResult = onResult
		_model = StateObject(wrappedValue: CardScannerViewModel(isRescan: isRescan, attemptNumber: attemptNumber))
	}

	var body: some View {
		ZStack {
			model.engine.makeCameraView()

			VStack(spacing: 16) {
				HStack {
					Button("Cancel") {
						model.end(.cancelled)
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
							.withoutInterpolatingText()
					}
					Text(model.guidance)
						.font(.subheadline)
						.multilineTextAlignment(.center)
						.foregroundStyle(.white)
						.padding(.horizontal, 24)
						.withoutInterpolatingText()

					if let onManualEntry {
						Button {
							model.end(.manualEntry)
							onManualEntry()
						} label: {
							Text("Enter card manually")
								.frame(minHeight: 44)
								.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
						.foregroundStyle(.white)
						.accessibilityIdentifier("manualCardEntryButton")
					}
				}
				.padding(.bottom, 24)
			}
		}
		.background(Color.black)
		.sdkScreen(AppAnalyticsScreen.cardScanner)
		.alert("Scanner", isPresented: $model.showsMessage) {
			Button("OK") {
				onCancel()
			}
		} message: {
			Text(model.message)
		}
		.onAppear {
			model.setCallbacks(onEnded: onEnded, onRetryableFailure: onRetryableFailure)
			UIAccessibility.post(notification: .announcement, argument: model.guidance)
		}
		.task {
			await model.consumeUpdates(
				onPermissionDenied: onPermissionDenied,
				onResult: onResult,
				onEnded: onEnded,
				onRetryableFailure: onRetryableFailure
			)
		}
		.onDisappear {
			model.end(.dismissed)
		}
		.onChange(of: scenePhase) { _, phase in
			guard phase == .background else { return }
			model.end(.dismissed, backgrounded: true)
			onCancel()
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
	private var ended = false
	private var hadCandidate = false
	private let attemptNumber: Int
	private var onEnded: ((CardScanEndMetrics) -> Void)?
	private var onRetryableFailure: ((CardScanRetryMetrics) -> Void)?

	init(isRescan: Bool, attemptNumber: Int = 1, engine: (any CardScanningEngine)? = nil) {
		self.attemptNumber = attemptNumber
		self.isRescan = isRescan
		self.engine = engine ?? CardScanningEngineFactory.make()
	}

	var isTorchAvailable: Bool {
		engine.isTorchAvailable
	}

	func setCallbacks(
		onEnded: @escaping (CardScanEndMetrics) -> Void,
		onRetryableFailure: @escaping (CardScanRetryMetrics) -> Void
	) {
		self.onEnded = onEnded
		self.onRetryableFailure = onRetryableFailure
	}

	func toggleTorch() {
		isTorchOn = engine.setTorchEnabled(!isTorchOn)
	}

	func consumeUpdates(
		onPermissionDenied: @escaping () -> Void,
		onResult: @escaping (CardScanResult, CardScanMetrics) -> Void,
		onEnded: @escaping (CardScanEndMetrics) -> Void = { _ in },
		onRetryableFailure: @escaping (CardScanRetryMetrics) -> Void = { _ in }
	) async {
		guard !stopped else { return }
		self.onEnded = onEnded
		self.onRetryableFailure = onRetryableFailure

		for await update in engine.scanUpdates() {
			guard !stopped else { return }
			switch update {
			case .permissionDenied:
				end(.permissionDenied)
				onPermissionDenied()
				return
			case .unsupported(let text):
				end(.unsupported)
				message = text
				showsMessage = true
				return
			case .failed(let text):
				end(.cameraUnavailable)
				message = text
				showsMessage = true
				return
			case .retryableFailure(let text):
				onRetryableFailure(CardScanRetryMetrics(
					engine: engine.engineID,
					elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
					hadCandidate: hadCandidate,
					isRescan: isRescan,
					attemptNumber: attemptNumber
				))
				candidateLastFour = nil
				candidateNetwork = nil
				guidance = text
			case .scanning(let text):
				guidance = text
			case .candidate(let lastFour, let network):
				hadCandidate = true
				if panDetectedAt == nil {
					panDetectedAt = Date()
				}
				candidateLastFour = lastFour
				candidateNetwork = network
				guidance = "Hold steady…"
			case .verified(let result):
				let metrics = metrics(for: result)
				end(.success)
				onResult(result, metrics)
				return
			}
		}
	}

	func end(_ outcome: CardScanEndMetrics.Outcome, backgrounded: Bool = false) {
		guard !ended else { return }
		ended = true
		var metrics = CardScanEndMetrics(
			engine: engine.engineID,
			outcome: outcome,
			elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
			hadCandidate: hadCandidate,
			timeToPANMs: panDetectedAt.map { Int($0.timeIntervalSince(startedAt) * 1000) },
			torchOn: isTorchOn,
			isRescan: isRescan,
			attemptNumber: attemptNumber
		)
		metrics.backgrounded = backgrounded
		stop()
		onEnded?(metrics)
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
