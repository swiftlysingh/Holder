#if os(iOS)
import ScanbotSDK
import SwiftUI

/// Scanbot custom credit-card scanner embedded in Holder's chrome.
@MainActor
final class ScanbotCardScanningEngine: NSObject, CardScanningEngine {
	let engineID = CardScanningEngineID.scanbot
	let showsCustomOverlay = true

	private let host = ScanbotCardScannerHostViewController()
	private var continuation: AsyncStream<CardScanUpdate>.Continuation?
	private var latestResult: CardScanResult?
	private var didStart = false
	private var didVerify = false

	override init() {
		super.init()
		host.delegate = self
	}

	func makeCameraView() -> AnyView {
		AnyView(ScanbotCardScannerRepresentable(host: host))
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
		host.stop()
		continuation?.finish()
		continuation = nil
	}

	private func startIfNeeded() {
		guard !didStart else { return }
		didStart = true
		if let licenseKey = AppSecrets.load().scanbotLicenseKey {
			Scanbot.setLicense(licenseKey)
		}
		host.start()
	}
}

extension ScanbotCardScanningEngine: ScanbotCardScannerHostDelegate {
	func scannerHostDidFail(_ message: String) {
		continuation?.yield(.failed(message))
	}

	func scannerHostDidScan(_ result: SBSDKCreditCardScanningResult) {
		guard !didVerify, let mapped = ScanbotCardResultMapper.result(from: result) else { return }
		if latestResult == nil {
			continuation?.yield(.candidate(lastFour: mapped.lastFour, network: mapped.network))
		}
		latestResult = mapped
		didVerify = true
		continuation?.yield(.verified(mapped))
		stop()
	}
}

enum ScanbotCardResultMapper {
	static func result(from scanned: SBSDKCreditCardScanningResult) -> CardScanResult? {
		let wrapper = scanned.creditCard?.wrap() as? SBSDKCreditCardDocumentModelCreditCard
		let rawNumber = wrapper?.cardNumber?.value?.text ?? field(named: "CardNumber", in: scanned)
		guard let rawNumber, let pan = CardPAN.validatedPAN(from: rawNumber, allowOCRNormalization: false) else {
			return nil
		}

		let expiryRaw = wrapper?.expiryDate?.value?.text ?? field(named: "ExpiryDate", in: scanned)
		let nameRaw = wrapper?.cardholderName?.value?.text ?? field(named: "CardholderName", in: scanned)

		return CardScanResult(
			pan: pan,
			expiry: expiryRaw.flatMap { CardExpiryParser.parse($0) },
			cardholderName: nameRaw.flatMap { CardholderNameParser.normalizedName($0) },
			network: CardPAN.network(for: pan)
		)
	}

	private static func field(named name: String, in scanned: SBSDKCreditCardScanningResult) -> String? {
		scanned.creditCard?.fields.first { field in
			field.type.name.localizedCaseInsensitiveContains(name)
		}?.value?.text
	}
}

private protocol ScanbotCardScannerHostDelegate: AnyObject {
	func scannerHostDidFail(_ message: String)
	func scannerHostDidScan(_ result: SBSDKCreditCardScanningResult)
}

private final class ScanbotCardScannerHostViewController: UIViewController, SBSDKCreditCardScannerViewControllerDelegate {
	weak var delegate: ScanbotCardScannerHostDelegate?
	private var scanner: SBSDKCreditCardScannerViewController?

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .black
	}

	func start() {
		guard scanner == nil else { return }
		let configuration = SBSDKCreditCardScannerConfiguration()
		configuration.requireExpiryDate = false
		configuration.requireCardholderName = false
		configuration.returnCreditCardImage = false
		scanner = SBSDKCreditCardScannerViewController(
			parentViewController: self,
			parentView: view,
			configuration: configuration,
			delegate: self
		)
	}

	func stop() {
		scanner = nil
	}

	func creditCardScannerViewController(
		_ controller: SBSDKCreditCardScannerViewController,
		didFailScanning error: any Error
	) {
		delegate?.scannerHostDidFail("Unable to scan this card. Try again or enter it manually.")
	}

	func creditCardScannerViewController(
		_ controller: SBSDKCreditCardScannerViewController,
		didScanCreditCard result: SBSDKCreditCardScanningResult
	) {
		delegate?.scannerHostDidScan(result)
	}
}

private struct ScanbotCardScannerRepresentable: UIViewControllerRepresentable {
	let host: ScanbotCardScannerHostViewController

	func makeUIViewController(context: Context) -> ScanbotCardScannerHostViewController {
		host
	}

	func updateUIViewController(_ uiViewController: ScanbotCardScannerHostViewController, context: Context) {}
}
#endif
