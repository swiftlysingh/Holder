// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "HolderCoreScratch",
	targets: [
		.target(name: "HolderCoreScratch"),
		.testTarget(
			name: "HolderCoreScratchTests",
			dependencies: ["HolderCoreScratch"]
		),
	]
)
