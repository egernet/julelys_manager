// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let argumentParser: Target.Dependency = .product(name: "ArgumentParser", package: "swift-argument-parser")
let platforms: [SupportedPlatform]? = {
#if os(OSX)
    return [.macOS(.v14)]
#else
    return nil
#endif
}()


let package = Package(
  name: "JulelysManager",
  platforms: platforms,
  products: [
    .executable(name: "JulelysMCP", targets: ["JulelysMCP"]),
    .executable(name: "JulelysManager", targets: ["JulelysManager"]),
    .executable(name: "JulelysWebMCP", targets: ["JulelysWebMCP"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.3"),
    .package(url: "https://github.com/egernet/swift_spi.git", from: "0.1.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
    .package(url: "https://github.com/egernet/SwiftJS.git", from: "1.3.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
  ],
  targets: [
    .executableTarget(
        name: "JulelysManager",
        dependencies: [
            argumentParser,
            .product(name: "SwiftSPI", package: "swift_spi"),
            .product(name: "SwiftJS", package: "SwiftJS"),
            "Entities"
        ],
        resources: [
            .copy("SequencesJS"),
            .copy("Resources")
        ]
    ),
    .executableTarget(
        name: "JulelysMCP",
        dependencies: [
            .product(name: "MCP", package: "swift-sdk"),
            "Entities"
        ]
    ),
    .executableTarget(
        name: "JulelysWebMCP",
        dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "MCP", package: "swift-sdk"),
            "Entities"
        ]
    ),
    .target(name: "Entities")
  ]
)
