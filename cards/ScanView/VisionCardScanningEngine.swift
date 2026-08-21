#if os(iOS)
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import Vision
import VisionKit

/// Live pass: DataScannerViewController (.balanced) over the whole card.
/// Once a PAN is stable, capture a still and run .accurate Vision verification.
@MainActor
final class VisionCardScanningEngine: NSObject, CardScanningEngine {
	let engineID = CardScanningEngineID.vision

	private let host = VisionScannerHostViewController()
	private var continuation: AsyncStream<CardScanUpdate>.Continuation?
	private var voter = TemporalPANVoter()
	private var stablePAN: String?
	private var latestObservation = CardFrameObservation()
	private var isStopping = false
	private var isVerifying = false
	private var didStart = false

	override init() {
		super.init()
		host.delegate = self
	}

	func makeCameraView() -> AnyView {
		AnyView(VisionScannerRepresentable(host: host))
	}

	func scanUpdates() -> AsyncStream<CardScanUpdate> {
		AsyncStream { continuation in
			self.continuation = continuation
			continuation.yield(.scanning(guidance: "Fit the whole card in the frame"))
			self.startIfNeeded()
		}
	}

	func verifyCurrentCandidate() async -> CardScanResult? {
		guard let pan = stablePAN else { return nil }

		if let image = await host.captureStill() {
			if let verified = await VisionStillVerifier.recognize(in: image) {
				return merge(still: verified, livePAN: pan)
			}
		}

		return CardScanSession.result(from: CardFrameObservation(
			pan: pan,
			expiry: latestObservation.expiry,
			cardholderName: latestObservation.cardholderName
		))
	}

	func stop() {
		isStopping = true
		host.stopScanning()
		continuation?.finish()
		continuation = nil
	}

	private func startIfNeeded() {
		guard !didStart else { return }
		didStart = true

		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			host.startScanning()
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
				Task { @MainActor in
					guard let self else { return }
					if granted {
						self.host.startScanning()
					} else {
						self.continuation?.yield(.permissionDenied)
					}
				}
			}
		case .denied, .restricted:
			continuation?.yield(.permissionDenied)
		@unknown default:
			continuation?.yield(.permissionDenied)
		}
	}

	private func merge(still: CardFrameObservation, livePAN: String) -> CardScanResult? {
		let pan = still.pan ?? livePAN
		guard CardPAN.validatedDigits(pan) != nil else { return nil }
		return CardScanResult(
			pan: pan,
			expiry: still.expiry ?? latestObservation.expiry,
			cardholderName: still.cardholderName ?? latestObservation.cardholderName,
			network: CardPAN.network(for: pan)
		)
	}
}

extension VisionCardScanningEngine: VisionScannerHostDelegate {
	func scannerHostDidFailUnsupported() {
		continuation?.yield(.unsupported("Card scanning needs a device camera. Enter the card manually, or try on an iPhone."))
	}

	func scannerHostDidFail(_ message: String) {
		continuation?.yield(.failed(message))
	}

	func scannerHostDidRecognize(_ items: [OCRTextItem]) {
		guard !isStopping, !isVerifying else { return }

		let observation = CardCandidateEngine.observe(items)
		if observation.pan != nil || observation.expiry != nil || observation.cardholderName != nil {
			latestObservation = CardFrameObservation(
				pan: observation.pan ?? latestObservation.pan,
				expiry: observation.expiry ?? latestObservation.expiry,
				cardholderName: observation.cardholderName ?? latestObservation.cardholderName
			)
		}

		guard let pan = observation.pan else { return }

		if stablePAN == nil {
			continuation?.yield(.candidate(lastFour: CardScanSession.lastFour(of: pan), network: CardPAN.network(for: pan)))
		}

		guard let winner = voter.record(pan) else { return }
		stablePAN = winner
		isVerifying = true
		continuation?.yield(.scanning(guidance: "Card number found. Checking the photo…"))

		Task { [weak self] in
			guard let self, !self.isStopping else { return }
			if let result = await self.verifyCurrentCandidate() {
				self.continuation?.yield(.verified(result))
			} else {
				self.continuation?.yield(.failed("Could not confirm the card number. Try again."))
				self.isVerifying = false
				self.stablePAN = nil
				self.voter.reset()
			}
		}
	}
}

@MainActor
private protocol VisionScannerHostDelegate: AnyObject {
	func scannerHostDidFailUnsupported()
	func scannerHostDidFail(_ message: String)
	func scannerHostDidRecognize(_ items: [OCRTextItem])
}

private final class VisionScannerHostViewController: UIViewController {
	weak var delegate: VisionScannerHostDelegate?
	private var scanner: DataScannerViewController?
	private var overlay: ScannerOverlayView?

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .black
	}

	func startScanning() {
		guard scanner == nil else { return }

		guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
			delegate?.scannerHostDidFailUnsupported()
			return
		}

		let controller = DataScannerViewController(
			recognizedDataTypes: [.text()],
			qualityLevel: .balanced,
			recognizesMultipleItems: true,
			isHighFrameRateTrackingEnabled: true,
			isPinchToZoomEnabled: true,
			isGuidanceEnabled: false,
			isHighlightingEnabled: true
		)
		controller.delegate = self
		addChild(controller)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(controller.view)
		NSLayoutConstraint.activate([
			controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			controller.view.topAnchor.constraint(equalTo: view.topAnchor),
			controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		controller.didMove(toParent: self)
		scanner = controller

		let overlay = ScannerOverlayView()
		overlay.translatesAutoresizingMaskIntoConstraints = false
		overlay.isUserInteractionEnabled = false
		view.addSubview(overlay)
		NSLayoutConstraint.activate([
			overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			overlay.topAnchor.constraint(equalTo: view.topAnchor),
			overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		self.overlay = overlay

		do {
			try controller.startScanning()
		} catch {
			delegate?.scannerHostDidFail("Unable to start the camera.")
		}
	}

	func stopScanning() {
		scanner?.stopScanning()
	}

	func captureStill() async -> UIImage? {
		return try? await scanner?.capturePhoto()
	}
}

extension VisionScannerHostViewController: DataScannerViewControllerDelegate {
	func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
		emit(allItems)
	}

	func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
		emit(allItems)
	}

	func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
		delegate?.scannerHostDidFail("The camera is unavailable.")
	}

	private func emit(_ items: [RecognizedItem]) {
		let ocrItems: [OCRTextItem] = items.compactMap { item in
			guard case .text(let text) = item else { return nil }
			let candidates = text.observation.topCandidates(5).map(\.string)
			return OCRTextItem(
				text: text.transcript,
				candidates: candidates,
				boundingBox: text.observation.boundingBox
			)
		}
		guard !ocrItems.isEmpty else { return }
		delegate?.scannerHostDidRecognize(ocrItems)
	}
}

private struct VisionScannerRepresentable: UIViewControllerRepresentable {
	let host: VisionScannerHostViewController

	func makeUIViewController(context: Context) -> VisionScannerHostViewController {
		host
	}

	func updateUIViewController(_ uiViewController: VisionScannerHostViewController, context: Context) {}
}

private final class ScannerOverlayView: UIView {
	private let cardAspect: CGFloat = 1.586

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .clear
		isOpaque = false
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		backgroundColor = .clear
		isOpaque = false
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		setNeedsDisplay()
	}

	override func draw(_ rect: CGRect) {
		guard let context = UIGraphicsGetCurrentContext() else { return }
		UIColor.black.withAlphaComponent(0.45).setFill()
		context.fill(bounds)

		let maxWidth = bounds.width * 0.86
		let width = min(maxWidth, bounds.height * 0.42 * cardAspect)
		let height = width / cardAspect
		let guide = CGRect(
			x: (bounds.width - width) / 2,
			y: (bounds.height - height) / 2,
			width: width,
			height: height
		)
		let path = UIBezierPath(roundedRect: guide, cornerRadius: 16)
		context.setBlendMode(.clear)
		path.fill()
		context.setBlendMode(.normal)

		UIColor.white.withAlphaComponent(0.9).setStroke()
		path.lineWidth = 2
		path.stroke()
	}
}

enum VisionStillVerifier {
	static func recognize(in image: UIImage) async -> CardFrameObservation? {
		guard let cgImage = image.cgImage else { return nil }

		let prepared = perspectiveCorrected(cgImage) ?? cgImage
		let items = await recognizeText(in: prepared, level: .accurate)
		guard !items.isEmpty else { return nil }
		return CardCandidateEngine.observe(items)
	}

	private static func perspectiveCorrected(_ cgImage: CGImage) -> CGImage? {
		let request = VNDetectRectanglesRequest()
		request.maximumObservations = 4
		request.minimumConfidence = 0.6
		request.minimumAspectRatio = 0.45
		request.maximumAspectRatio = 2.0
		let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
		do {
			try handler.perform([request])
		} catch {
			return nil
		}

		guard let rectangle = (request.results ?? []).max(by: { lhs, rhs in
			lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
		}) else {
			return nil
		}

		return flattened(cgImage, observation: rectangle)
	}

	private static func flattened(_ cgImage: CGImage, observation: VNRectangleObservation) -> CGImage? {
		let ciImage = CIImage(cgImage: cgImage)
		let size = CGSize(width: cgImage.width, height: cgImage.height)
		func point(_ vn: CGPoint) -> CGPoint {
			CGPoint(x: vn.x * size.width, y: vn.y * size.height)
		}

		let filter = CIFilter.perspectiveCorrection()
		filter.inputImage = ciImage
		filter.topLeft = point(observation.topLeft)
		filter.topRight = point(observation.topRight)
		filter.bottomLeft = point(observation.bottomLeft)
		filter.bottomRight = point(observation.bottomRight)

		guard let output = filter.outputImage else { return nil }
		let context = CIContext(options: nil)
		return context.createCGImage(output, from: output.extent)
	}

	private static func recognizeText(in cgImage: CGImage, level: VNRequestTextRecognitionLevel) async -> [OCRTextItem] {
		await withCheckedContinuation { continuation in
			let request = VNRecognizeTextRequest { request, _ in
				let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
				let items = observations.map { observation in
					let candidates = observation.topCandidates(5).map(\.string)
					return OCRTextItem(
						text: candidates.first ?? "",
						candidates: candidates,
						boundingBox: observation.boundingBox
					)
				}
				continuation.resume(returning: items)
			}
			request.recognitionLevel = level
			request.usesLanguageCorrection = false
			let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
			do {
				try handler.perform([request])
			} catch {
				continuation.resume(returning: [])
			}
		}
	}
}
#endif
