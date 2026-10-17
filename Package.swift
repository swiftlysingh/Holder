// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "Holder",
	targets: [
		.target(
			name: "HolderCore",
			path: "cards",
			sources: [
				"Extensions.swift",
				"Model/CardData.swift",
				"ScanView/CardCandidateEngine.swift",
				"ScanView/LinuxGeometry.swift",
			],
			swiftSettings: [
				.swiftLanguageMode(.v5)
			]
		),
		.testTarget(
			name: "HolderCoreTests",
			dependencies: ["HolderCore"],
			path: "cardsTests",
			sources: ["CardCandidateEngineTests.swift"],
			swiftSettings: [
				.swiftLanguageMode(.v5)
			]
		),
	]
)
