// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "GymAppNativeCore",
  platforms: [
    .iOS(.v17),
    .watchOS(.v10),
    .macOS(.v14),
  ],
  products: [
    .library(name: "GymAppNativeCore", targets: ["GymAppNativeCore"]),
  ],
  targets: [
    .target(name: "GymAppNativeCore"),
    .testTarget(
      name: "GymAppNativeCoreTests",
      dependencies: ["GymAppNativeCore"],
    ),
  ],
)
