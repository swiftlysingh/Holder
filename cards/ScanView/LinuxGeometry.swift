#if !canImport(CoreGraphics)
struct CGPoint: Equatable, Sendable {
	var x: Double
	var y: Double
}

struct CGSize: Equatable, Sendable {
	var width: Double
	var height: Double
}

struct CGRect: Equatable, Sendable {
	var origin: CGPoint
	var size: CGSize

	static let zero = CGRect(x: 0, y: 0, width: 0, height: 0)

	init(x: Double, y: Double, width: Double, height: Double) {
		origin = CGPoint(x: x, y: y)
		size = CGSize(width: width, height: height)
	}

	var minX: Double { origin.x }
	var minY: Double { origin.y }
	var maxY: Double { origin.y + size.height }
}
#endif
