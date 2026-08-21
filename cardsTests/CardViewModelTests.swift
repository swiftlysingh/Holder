import XCTest
@testable import Holder

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class CardViewModelTests: XCTestCase {
	func testInitDoesNotWaitForCardImageLoad() async {
		let imageStore = GatedCardImageStore()
		let model = makeModel(imageStore: imageStore)

		XCTAssertNil(model.cardImage)

		await imageStore.waitUntilLoadStarts()
		XCTAssertNil(model.cardImage)

		await imageStore.completeLoad(with: nil)
		await Task.yield()
		XCTAssertNil(model.cardImage)
	}

	func testICloudDirectoryRetriesAfterTransientUnavailability() async throws {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("holder-icloud-test-\(UUID().uuidString)", isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }

		let resolver = SequentialDirectoryResolver(results: [nil, directory])
		let manager = ICloudDataManager(directoryResolver: { resolver.resolve() })
		let identifier = UUID()

		let initialData = await manager.loadImageData(for: identifier)
		XCTAssertNil(initialData)

		let imageData = try XCTUnwrap(makeTestImage().jpegData(compressionQuality: 0.8))
		let didSave = await manager.saveImageData(imageData, for: identifier)
		XCTAssertTrue(didSave)

		let recoveredData = await manager.loadImageData(for: identifier)
		XCTAssertEqual(recoveredData, imageData)
		XCTAssertEqual(resolver.callCount, 2)
		XCTAssertFalse(resolver.didResolveOnMainThread)
	}

	private func makeModel(imageStore: CardImageStore) -> CardViewModel {
		CardViewModel(
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
	}

	private func makeTestImage() -> PlatformImage {
		#if os(macOS)
		let image = NSImage(size: NSSize(width: 1, height: 1))
		image.lockFocus()
		NSColor.red.setFill()
		NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1, height: 1)).fill()
		image.unlockFocus()
		return image
		#else
		return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
		}
		#endif
	}
}

private final class GatedCardImageStore: CardImageStore, @unchecked Sendable {
	private let lock = NSLock()
	private var loadContinuation: CheckedContinuation<Data?, Never>?
	private var startedContinuation: CheckedContinuation<Void, Never>?
	private var loadStarted = false

	func waitUntilLoadStarts() async {
		await withCheckedContinuation { continuation in
			let loadAlreadyStarted = lock.withLock {
				guard !loadStarted else { return true }
				startedContinuation = continuation
				return false
			}
			if loadAlreadyStarted {
				continuation.resume()
			}
		}
	}

	func completeLoad(with data: Data?) async {
		let continuation = lock.withLock {
			let continuation = loadContinuation
			loadContinuation = nil
			return continuation
		}
		continuation?.resume(returning: data)
	}

	func loadImageData(for uuid: UUID) async -> Data? {
		await withCheckedContinuation { continuation in
			let started = lock.withLock {
				loadContinuation = continuation
				loadStarted = true
				let started = startedContinuation
				startedContinuation = nil
				return started
			}
			started?.resume()
		}
	}

	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool { false }

	func deleteImage(for uuid: UUID) async {}
}

private final class SequentialDirectoryResolver: @unchecked Sendable {
	private let lock = NSLock()
	private var results: [URL?]
	private var callCountStorage = 0
	private var didResolveOnMainThreadStorage = false

	init(results: [URL?]) {
		self.results = results
	}

	func resolve() -> URL? {
		lock.lock()
		defer { lock.unlock() }
		callCountStorage += 1
		didResolveOnMainThreadStorage = didResolveOnMainThreadStorage || Thread.isMainThread
		return results.isEmpty ? nil : results.removeFirst()
	}

	var callCount: Int {
		lock.lock()
		defer { lock.unlock() }
		return callCountStorage
	}

	var didResolveOnMainThread: Bool {
		lock.lock()
		defer { lock.unlock() }
		return didResolveOnMainThreadStorage
	}
}
