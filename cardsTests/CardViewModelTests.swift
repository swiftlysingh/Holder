import XCTest
@testable import Holder

@MainActor
final class CardViewModelTests: XCTestCase {
	func testInitDoesNotWaitForCardImageLoad() async {
		let imageStore = GatedCardImageStore()
		let model = CardViewModel(
			card: CardData(
				id: UUID(),
				number: "4111111111111111",
				cvv: "123",
				expiration: "12/30",
				name: "Test Card",
				description: "",
				type: .creditCard
			),
			addUpdateCard: { _ in true },
			imageStore: imageStore
		)

		XCTAssertNil(model.cardImage)

		await imageStore.waitUntilLoadStarts()
		XCTAssertNil(model.cardImage)

		await imageStore.completeLoad(with: nil)
		await Task.yield()
		XCTAssertNil(model.cardImage)
	}
}

private final class GatedCardImageStore: CardImageStore, @unchecked Sendable {
	private let lock = NSLock()
	private var loadContinuation: CheckedContinuation<PlatformImage?, Never>?
	private var startedContinuation: CheckedContinuation<Void, Never>?
	private var loadStarted = false

	func waitUntilLoadStarts() async {
		lock.lock()
		if loadStarted {
			lock.unlock()
			return
		}
		lock.unlock()
		await withCheckedContinuation { continuation in
			lock.lock()
			if loadStarted {
				lock.unlock()
				continuation.resume()
				return
			}
			startedContinuation = continuation
			lock.unlock()
		}
	}

	func completeLoad(with image: PlatformImage?) async {
		lock.lock()
		let continuation = loadContinuation
		loadContinuation = nil
		lock.unlock()
		continuation?.resume(returning: image)
	}

	func loadImage(for uuid: UUID) async -> PlatformImage? {
		await withCheckedContinuation { continuation in
			lock.lock()
			loadContinuation = continuation
			loadStarted = true
			let started = startedContinuation
			startedContinuation = nil
			lock.unlock()
			started?.resume()
		}
	}

	func saveImage(_ image: PlatformImage, for uuid: UUID) async -> Bool { false }

	func deleteImage(for uuid: UUID) async {}
}
