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

	func testImageDataNormalizerConvertsPNGToJPEG() throws {
		let png = try makePNGData()

		let jpeg = try XCTUnwrap(CardImageData.normalizedJPEG(from: png))

		XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8])
		XCTAssertNotEqual(jpeg, png)
		XCTAssertNotNil(PlatformImage(data: jpeg))
	}

	func testLoadingExistingImageDoesNotRewriteItsData() async throws {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("holder-existing-image-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }

		let identifier = UUID()
		let imageURL = directory.appendingPathComponent("\(identifier.uuidString).jpg")
		let existingData = try makePNGData()
		try existingData.write(to: imageURL)
		let manager = ICloudDataManager(directoryResolver: { directory })

		let loadedData = await manager.loadImageData(for: identifier)

		XCTAssertEqual(loadedData, existingData)
		XCTAssertEqual(try Data(contentsOf: imageURL), existingData)
	}

	func testICloudDirectoryRetriesAndNormalizesAfterTransientUnavailability() async throws {
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
		let imageData = try makePNGData()

		let initialData = await manager.loadImageData(for: identifier)
		XCTAssertNil(initialData)

		let failedSave = await manager.saveImageData(imageData, for: identifier)
		XCTAssertFalse(failedSave)

		let didSave = await manager.saveImageData(imageData, for: identifier)
		XCTAssertTrue(didSave)

		let recoveredData = await manager.loadImageData(for: identifier)
		let jpegData = try XCTUnwrap(recoveredData)
		XCTAssertEqual(Array(jpegData.prefix(2)), [0xFF, 0xD8])
		XCTAssertNotNil(PlatformImage(data: jpegData))
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

	private func makePNGData() throws -> Data {
		#if os(macOS)
		let bitmap = try XCTUnwrap(NSBitmapImageRep(
			bitmapDataPlanes: nil,
			pixelsWide: 1,
			pixelsHigh: 1,
			bitsPerSample: 8,
			samplesPerPixel: 4,
			hasAlpha: true,
			isPlanar: false,
			colorSpaceName: .deviceRGB,
			bytesPerRow: 4,
			bitsPerPixel: 32
		))
		bitmap.setColor(.red, atX: 0, y: 0)
		return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
		#else
		let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
		let image = renderer.image { context in
			UIColor.red.setFill()
			context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
		}
		return try XCTUnwrap(image.pngData())
		#endif
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
