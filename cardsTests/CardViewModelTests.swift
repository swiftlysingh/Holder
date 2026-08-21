import XCTest
@testable import Holder

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
		let unusableDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("holder-icloud-file-\(UUID().uuidString)")
		try Data("not a directory".utf8).write(to: unusableDirectory)
		defer {
			try? FileManager.default.removeItem(at: directory)
			try? FileManager.default.removeItem(at: unusableDirectory)
		}

		let resolver = SequentialDirectoryResolver(results: [nil, unusableDirectory, directory])
		let manager = ICloudDataManager(directoryResolver: { resolver.resolve() })
		let identifier = UUID()
		let imageData = Data("image".utf8)

		let initialData = await manager.loadImageData(for: identifier)
		XCTAssertNil(initialData)

		let failedSave = await manager.saveImageData(imageData, for: identifier)
		XCTAssertFalse(failedSave)

		let didSave = await manager.saveImageData(imageData, for: identifier)
		XCTAssertTrue(didSave)

		let recoveredData = await manager.loadImageData(for: identifier)
		XCTAssertEqual(recoveredData, imageData)
		XCTAssertEqual(resolver.callCount, 3)
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
}

private actor GatedCardImageStore: CardImageStore {
	private var loadContinuation: CheckedContinuation<Data?, Never>?
	private var startedContinuation: CheckedContinuation<Void, Never>?
	private var loadStarted = false

	func waitUntilLoadStarts() async {
		if loadStarted { return }
		await withCheckedContinuation { startedContinuation = $0 }
	}

	func completeLoad(with data: Data?) async {
		loadContinuation?.resume(returning: data)
		loadContinuation = nil
	}

	func loadImageData(for uuid: UUID) async -> Data? {
		await withCheckedContinuation { continuation in
			loadContinuation = continuation
			loadStarted = true
			let started = startedContinuation
			startedContinuation = nil
			started?.resume()
		}
	}

	func saveImageData(_ data: Data, for uuid: UUID) async -> Bool { false }

	func deleteImage(for uuid: UUID) async -> Bool { true }
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
		lock.withLock {
			callCountStorage += 1
			didResolveOnMainThreadStorage = didResolveOnMainThreadStorage || Thread.isMainThread
			return results.isEmpty ? nil : results.removeFirst()
		}
	}

	var callCount: Int {
		lock.withLock { callCountStorage }
	}

	var didResolveOnMainThread: Bool {
		lock.withLock { didResolveOnMainThreadStorage }
	}
}
