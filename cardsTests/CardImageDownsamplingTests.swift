import UniformTypeIdentifiers
import XCTest
@testable import Holder

final class CardImageDownsamplingTests: XCTestCase {
	func testDownsampledImageCapsTheLongestEdge() throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let image = try XCTUnwrap(CardImageData.downsampledImage(from: data, maxPixelSize: 100))
		let size = CardImageData.pixelSize(of: image)

		XCTAssertLessThanOrEqual(max(size.width, size.height), 100)
		XCTAssertGreaterThan(min(size.width, size.height), 0)
	}

	func testDownsampledImageKeepsSmallPhotosUnderTheCap() throws {
		let data = try makeJPEGData(width: 80, height: 60)
		let image = try XCTUnwrap(CardImageData.downsampledImage(from: data, maxPixelSize: 2048))
		let size = CardImageData.pixelSize(of: image)

		XCTAssertEqual(size.width, 80, accuracy: 1)
		XCTAssertEqual(size.height, 60, accuracy: 1)
	}

	func testDownsampledImageReturnsNilForInvalidData() {
		XCTAssertNil(CardImageData.downsampledImage(from: Data("not-an-image".utf8)))
	}

	func testNormalizedJPEGCapsTheLongestEdge() throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let jpeg = try XCTUnwrap(CardImageData.normalizedJPEG(from: data, maxPixelSize: 100))
		let image = try XCTUnwrap(CardImageData.downsampledImage(from: jpeg, maxPixelSize: 2048))
		let size = CardImageData.pixelSize(of: image)

		XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8])
		XCTAssertLessThanOrEqual(max(size.width, size.height), 100)
	}

	func testDefaultMaxPixelSizeFitsOnScreenWithout48MPBitmaps() {
		XCTAssertEqual(CardImageData.maxPixelSize, 2048)
	}

	func testDecodeOffMainReturnsADownsampledImage() async throws {
		let data = try makeJPEGData(width: 400, height: 300)
		let decoded = await CardImageData.decodeOffMain(data)
		let image = try XCTUnwrap(decoded)
		let size = CardImageData.pixelSize(of: image)

		XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(CardImageData.maxPixelSize))
		XCTAssertGreaterThan(min(size.width, size.height), 0)
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
