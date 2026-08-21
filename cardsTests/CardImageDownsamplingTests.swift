import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Holder

#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class CardImageDownsamplingTests: XCTestCase {
	func testDownsampledImageCapsTheLongestEdge() throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let image = try XCTUnwrap(ICloudDataManager.downsampledImage(from: data, maxPixelSize: 100))
		let size = ICloudDataManager.pixelSize(of: image)

		XCTAssertLessThanOrEqual(max(size.width, size.height), 100)
		XCTAssertGreaterThan(min(size.width, size.height), 0)
	}

	func testDownsampledImageKeepsSmallPhotosUnderTheCap() throws {
		let data = try makeJPEGData(width: 80, height: 60)
		let image = try XCTUnwrap(ICloudDataManager.downsampledImage(from: data, maxPixelSize: 2048))
		let size = ICloudDataManager.pixelSize(of: image)

		XCTAssertEqual(size.width, 80, accuracy: 1)
		XCTAssertEqual(size.height, 60, accuracy: 1)
	}

	func testDownsampledImageReturnsNilForInvalidData() {
		XCTAssertNil(ICloudDataManager.downsampledImage(from: Data("not-an-image".utf8)))
	}

	func testDownsampledImageFromMissingFileReturnsNil() {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("jpg")
		XCTAssertNil(ICloudDataManager.downsampledImage(fromFile: url))
	}

	func testDownsampledImageFromFileMatchesDataPath() throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("jpg")
		try data.write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }

		let fromFile = try XCTUnwrap(ICloudDataManager.downsampledImage(fromFile: url, maxPixelSize: 100))
		let fromData = try XCTUnwrap(ICloudDataManager.downsampledImage(from: data, maxPixelSize: 100))

		XCTAssertEqual(ICloudDataManager.pixelSize(of: fromFile).width, ICloudDataManager.pixelSize(of: fromData).width, accuracy: 1)
		XCTAssertEqual(ICloudDataManager.pixelSize(of: fromFile).height, ICloudDataManager.pixelSize(of: fromData).height, accuracy: 1)
	}

	func testConstrainedImageDownsamplesDecodedBitmaps() throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let decoded = try XCTUnwrap(platformImage(from: data))
		let constrained = ICloudDataManager.constrainedImage(decoded, maxPixelSize: 100)
		let size = ICloudDataManager.pixelSize(of: constrained)

		XCTAssertLessThanOrEqual(max(size.width, size.height), 100)
	}

	func testConstrainedImageLeavesSmallBitmapsAlone() throws {
		let data = try makeJPEGData(width: 80, height: 60)
		let decoded = try XCTUnwrap(platformImage(from: data))
		let constrained = ICloudDataManager.constrainedImage(decoded, maxPixelSize: 2048)
		let size = ICloudDataManager.pixelSize(of: constrained)

		XCTAssertEqual(size.width, ICloudDataManager.pixelSize(of: decoded).width, accuracy: 1)
		XCTAssertEqual(size.height, ICloudDataManager.pixelSize(of: decoded).height, accuracy: 1)
	}

	func testDefaultMaxPixelSizeFitsOnScreenWithout48MPBitmaps() {
		XCTAssertEqual(ICloudDataManager.maxPixelSize, 2048)
	}

	private func platformImage(from data: Data) -> PlatformImage? {
		#if os(macOS)
		NSImage(data: data)
		#else
		UIImage(data: data)
		#endif
	}

	private func makeJPEGData(width: Int, height: Int) throws -> Data {
		struct FixtureError: Error {}

		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
		for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
			pixels[index] = 200
			pixels[index + 1] = 40
			pixels[index + 2] = 40
			pixels[index + 3] = 255
		}

		let cgImage = try pixels.withUnsafeMutableBytes { buffer -> CGImage in
			let colorSpace = CGColorSpaceCreateDeviceRGB()
			guard let baseAddress = buffer.baseAddress,
				  let context = CGContext(
					data: baseAddress,
					width: width,
					height: height,
					bitsPerComponent: 8,
					bytesPerRow: bytesPerRow,
					space: colorSpace,
					bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
				  ),
				  let image = context.makeImage() else {
				throw FixtureError()
			}
			return image
		}

		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			data,
			UTType.jpeg.identifier as CFString,
			1,
			nil
		) else {
			throw FixtureError()
		}
		CGImageDestinationAddImage(destination, cgImage, nil)
		guard CGImageDestinationFinalize(destination) else {
			throw FixtureError()
		}
		return data as Data
	}
}
