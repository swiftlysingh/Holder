#if os(iOS)
import AVFoundation
import BlinkCard
import SwiftUI

/// Headless BlinkCard session behind Holder's scanner chrome.
@MainActor
final class BlinkCardScanningEngine: NSObject, CardScanningEngine {
	let engineID = CardScanningEngineID.blinkCard
	let showsCustomOverlay = true

	private let host = BlinkCardCameraHostViewController()
	private var continuation: AsyncStream<CardScanUpdate>.Continuation?
	private var sdk: BlinkCardSdk?
	private var session: BlinkCardSession?
	private var latestResult: CardScanResult?
	private var isStopping = false
	private var didStart = false
	private var didVerify = false

	override init() {
		super.init()
		host.onFrame = { [weak self] sampleBuffer in
			self?.process(sampleBuffer)
		}
	}

	func makeCameraView() -> AnyView {
		AnyView(BlinkCardCameraRepresentable(host: host))
	}

	func scanUpdates() -> AsyncStream<CardScanUpdate> {
		AsyncStream { continuation in
			self.continuation = continuation
			continuation.yield(.scanning(guidance: "Fit the whole card in the frame"))
			self.startIfNeeded()
		}
	}

	func verifyCurrentCandidate() async -> CardScanResult? {
		latestResult
	}

	func stop() {
		isStopping = true
		host.stop()
		session?.cancelActiveProcessing()
		continuation?.finish()
		continuation = nil
	}

	private func startIfNeeded() {
		guard !didStart else { return }
		didStart = true

		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			Task { await bootstrap() }
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
				Task { @MainActor in
					if granted {
						await self?.bootstrap()
					} else {
						self?.continuation?.yield(.permissionDenied)
					}
				}
			}
		case .denied, .restricted:
			continuation?.yield(.permissionDenied)
		@unknown default:
			continuation?.yield(.permissionDenied)
		}
	}

	private func bootstrap() async {
		guard let licenseKey = AppSecrets.load().blinkCardLicenseKey else {
			continuation?.yield(.failed("Add a BlinkCardLicenseKey to Secrets.plist to run the BlinkCard trial."))
			return
		}

		do {
			let settings = BlinkCardSdkSettings(
				licenseKey: licenseKey,
				downloadResources: true
			)
			let sdk = try await BlinkCardSdk.createBlinkCardSdk(withSettings: settings)
			let sessionSettings = BlinkCardSessionSettings(
				inputImageSource: .video,
				scanningMode: .automatic,
				scanningSettings: ScanningSettings(
					extractionSettings: ExtractionSettings(
						extractIban: false,
						extractExpiryDate: true,
						extractCardholderName: true,
						extractCvv: false,
						extractInvalidCardNumber: false
					)
				)
			)
			self.sdk = sdk
			self.session = await sdk.createScanningSession(settings: sessionSettings)
			host.start()
		} catch {
			continuation?.yield(.failed("BlinkCard failed to start. Check the trial license and network for model download."))
		}
	}

	private func process(_ sampleBuffer: CMSampleBuffer) {
		guard !isStopping, !didVerify, let session else { return }

		let frame = CameraFrame(
			buffer: MBSampleBufferWrapper(cmSampleBuffer: sampleBuffer),
			roi: RegionOfInterest(x: 0, y: 0, width: 1, height: 1),
			orientation: .portrait
		)
		let inputImage = InputImage(cameraFrame: frame)

		Task { [weak self] in
			guard let self, !self.isStopping else { return }
			let frameResult = await session.process(inputImage: inputImage)
			let status = frameResult.processResult?.resultCompleteness.scanningStatus
			let numberStatus = frameResult.processResult?.resultCompleteness.cardNumberExtractionStatus

			if numberStatus == .extracted || status == .cardScanned || status == .documentScanned {
				let scanned = await session.getResult()
				await MainActor.run {
					self.handle(scanned, complete: status == .cardScanned || status == .documentScanned)
				}
			}
		}
	}

	private func handle(_ scanned: BlinkCardScanningResult, complete: Bool) {
		guard !didVerify, let result = BlinkCardResultMapper.result(from: scanned) else { return }

		if latestResult == nil {
			continuation?.yield(.candidate(lastFour: result.lastFour, network: result.network))
		}
		latestResult = result

		if complete {
			didVerify = true
			continuation?.yield(.verified(result))
			stop()
		} else {
			continuation?.yield(.scanning(guidance: "Hold steady…"))
		}
	}
}

enum BlinkCardResultMapper {
	static func result(from scanned: BlinkCardScanningResult) -> CardScanResult? {
		guard let account = scanned.cardAccounts.first else { return nil }
		let rawNumber = account.cardNumber
		guard let pan = CardPAN.validatedPAN(from: rawNumber, allowOCRNormalization: false) else {
			return nil
		}

		let expiry: String?
		if let date = account.expiryDate {
			if let original = date.originalString, let parsed = CardExpiryParser.parse(original) {
				expiry = parsed
			} else if let month = date.month, let year = date.year {
				expiry = CardExpiryParser.validated(month: String(format: "%02d", month), year: String(year), now: Date())
			} else {
				expiry = nil
			}
		} else {
			expiry = nil
		}

		let name = scanned.cardholderName?.trimmingCharacters(in: .whitespacesAndNewlines)
		return CardScanResult(
			pan: pan,
			expiry: expiry,
			cardholderName: (name?.isEmpty == false) ? name : CardholderNameParser.normalizedName(name ?? ""),
			network: CardPAN.network(for: pan)
		)
	}
}

private final class BlinkCardCameraHostViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
	var onFrame: ((CMSampleBuffer) -> Void)?
	private let captureSession = AVCaptureSession()
	private let sessionQueue = DispatchQueue(label: "holder.blinkcard.camera")
	private let outputQueue = DispatchQueue(label: "holder.blinkcard.frames")
	private var previewLayer: AVCaptureVideoPreviewLayer?
	private var isProcessing = false

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .black
		let preview = AVCaptureVideoPreviewLayer(session: captureSession)
		preview.videoGravity = .resizeAspectFill
		view.layer.addSublayer(preview)
		previewLayer = preview
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		previewLayer?.frame = view.bounds
	}

	func start() {
		sessionQueue.async { [weak self] in
			self?.configureSession()
			self?.captureSession.startRunning()
		}
	}

	func stop() {
		sessionQueue.async { [weak self] in
			self?.captureSession.stopRunning()
		}
	}

	private func configureSession() {
		guard captureSession.inputs.isEmpty else { return }
		captureSession.beginConfiguration()
		captureSession.sessionPreset = .hd1920x1080

		let discovery = AVCaptureDevice.DiscoverySession(
			deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
			mediaType: .video,
			position: .back
		)
		guard let device = discovery.devices.first,
			  let input = try? AVCaptureDeviceInput(device: device),
			  captureSession.canAddInput(input) else {
			captureSession.commitConfiguration()
			return
		}
		captureSession.addInput(input)

		let output = AVCaptureVideoDataOutput()
		output.alwaysDiscardsLateVideoFrames = true
		output.setSampleBufferDelegate(self, queue: outputQueue)
		if captureSession.canAddOutput(output) {
			captureSession.addOutput(output)
		}
		output.connection(with: .video)?.preferredVideoStabilizationMode = .auto
		captureSession.commitConfiguration()

		try? device.lockForConfiguration()
		device.autoFocusRangeRestriction = .near
		device.unlockForConfiguration()
	}

	func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		guard !isProcessing else { return }
		isProcessing = true
		DispatchQueue.main.async { [weak self] in
			self?.onFrame?(sampleBuffer)
			self?.isProcessing = false
		}
	}
}

private struct BlinkCardCameraRepresentable: UIViewControllerRepresentable {
	let host: BlinkCardCameraHostViewController

	func makeUIViewController(context: Context) -> BlinkCardCameraHostViewController {
		host
	}

	func updateUIViewController(_ uiViewController: BlinkCardCameraHostViewController, context: Context) {}
}
#endif
