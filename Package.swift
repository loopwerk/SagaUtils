// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "SagaUtils",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "SagaUtils",
      targets: ["SagaUtils"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/loopwerk/Saga.git", "2.0.3"..<"4.0.0"),
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
  ],
  targets: [
    .target(
      name: "SagaUtils",
      dependencies: [
        "Saga",
        "SwiftSoup",
      ]
    ),
    .testTarget(
      name: "SagaUtilsTests",
      dependencies: [
        "SagaUtils",
        "SwiftSoup",
        "Saga",
      ]
    ),
  ]
)
