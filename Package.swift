// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let argumentParser: Target.Dependency = .product(name: "ArgumentParser", package: "swift-argument-parser")
let platforms: [SupportedPlatform]? = {
#if os(OSX)
    return [.macOS(.v13)]
#else
    return nil
#endif
}()


let package = Package(
  name: "JulelysManager",
  platforms: platforms,
  products: [
    .executable(name: "JulelysMCP", targets: ["JulelysMCP"]),
    .executable(name: "JulelysManager", targets: ["JulelysManager"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.3"),
    .package(url: "https://github.com/egernet/swift_spi.git", from: "0.1.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
    .package(url: "https://github.com/ptliddle/swifty-json-schema.git", from: "0.1.0")
  ],
  targets: [
    .target(
        name: "elk"
    ),
    .executableTarget(
        name: "JulelysManager",
        dependencies: [
            argumentParser,
            "elk",
            .product(name: "SwiftSPI", package: "swift_spi"),
            "Entities"
        ],
        resources: [
            .copy("SequencesJS")
        ]
    ),
    .executableTarget(
        name: "JulelysMCP",
        dependencies: [
            .product(name: "MCP", package: "swift-sdk"),
            .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
            "Entities"
        ]
    ),
    .target(name: "Entities")
  ]
)
