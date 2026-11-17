import XCTest
@testable import Holder

final class ScannerRecognitionRegressionTests: XCTestCase {
	func testReconstructsUnevenlySplitPANGroups() {
		let items = [
			OCRTextItem(text: "4111111111"),
			OCRTextItem(text: "111111")
		]

		XCTAssertEqual(CardCandidateEngine.reconstructPANs(from: items), ["4111111111111111"])
	}
}

#if os(iOS)
import UIKit

final class VisionStillVerifierRegressionTests: XCTestCase {
	private let visa = CardFrameObservation(pan: "4111111111111111", expiry: nil, cardholderName: nil)
	private let mastercard = CardFrameObservation(pan: "5555555555554444", expiry: nil, cardholderName: nil)

	private var futureExpiry: String {
		let year = Calendar(identifier: .gregorian).component(.year, from: Date())
		return String(format: "12/%02d", (year + 2) % 100)
	}

	@MainActor
	func testRecognizesPANFromAStillImage() async {
		let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 630)).image { context in
			UIColor.white.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 1000, height: 630))
			("4111 1111 1111 1111" as NSString).draw(
				at: CGPoint(x: 80, y: 250),
				withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 60, weight: .regular),
					.foregroundColor: UIColor.black]
			)
		}

		let result = await VisionStillVerifier.recognize(in: image, expecting: visa.pan!)

		XCTAssertEqual(result?.pan, visa.pan)
	}

	func testOriginalPhotoCanRecoverLivePANWhenRectificationConflicts() {
		let result = VisionStillVerifier.preferredObservation(
			corrected: mastercard,
			original: visa,
			expecting: visa.pan!
		)

		XCTAssertEqual(result, visa)
	}

	func testExpectedPANSelectionDropsMetadataWhenAnotherPANWasPreferred() {
		let items = [
			OCRTextItem(text: mastercard.pan!),
			OCRTextItem(text: visa.pan!),
			OCRTextItem(text: futureExpiry),
			OCRTextItem(text: "JANE DOE")
		]
		let preferred = CardCandidateEngine.observe(items)
		XCTAssertEqual(preferred.pan, mastercard.pan)
		XCTAssertEqual(preferred.expiry, futureExpiry)
		XCTAssertEqual(preferred.cardholderName, "JANE DOE")

		let result = VisionStillVerifier.observation(from: items, expecting: visa.pan!)

		XCTAssertEqual(result?.pan, visa.pan)
		XCTAssertNil(result?.expiry)
		XCTAssertNil(result?.cardholderName)
	}

	func testExpectedPANPreservesMetadataWhenAlreadyPreferred() {
		let items = [
			OCRTextItem(text: visa.pan!),
			OCRTextItem(text: futureExpiry),
			OCRTextItem(text: "JANE DOE")
		]

		let result = VisionStillVerifier.observation(from: items, expecting: visa.pan!)

		XCTAssertEqual(result?.pan, visa.pan)
		XCTAssertEqual(result?.expiry, futureExpiry)
		XCTAssertEqual(result?.cardholderName, "JANE DOE")
	}

	func testDetectedConflictingPANIsPreservedWhenOtherImageHasNoPAN() {
		let metadataOnly = CardFrameObservation(pan: nil, expiry: "09/29", cardholderName: nil)

		let result = VisionStillVerifier.preferredObservation(
			corrected: metadataOnly,
			original: mastercard,
			expecting: visa.pan!
		)

		XCTAssertEqual(result, mastercard)
	}

	func testConflictingPANIsPreservedWhenNeitherImageMatches() {
		let result = VisionStillVerifier.preferredObservation(
			corrected: mastercard,
			original: nil,
			expecting: visa.pan!
		)

		XCTAssertEqual(result, mastercard)
	}
}
#endif
