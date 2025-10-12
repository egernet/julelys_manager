// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let argumentParser: Target.Dependency = .product(name: "ArgumentParser", package: "swift-argument-parser")
let plugins: [Target.PluginUsage]? = {
#if os(OSX)
    let swiftGenPlugin: Target.PluginUsage = .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
    return [swiftGenPlugin]
#else
    return nil
#endif
}()

let platforms: [SupportedPlatform]? = {
#if os(OSX)
    return [.macOS(.v12)]
#else
    return nil
#endif
}()


let package = Package(
  name: "JulelysManager",
  platforms: platforms,
  products: [
    .executable(name: "JulelysManager", targets: ["JulelysManager"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.3"),
    .package(url: "https://github.com/SimplyDanny/SwiftLint", from: "0.61.0"),
    .package(url: "https://github.com/egernet/swift_spi.git", from: "0.1.0")
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
            .product(name: "SwiftSPI", package: "swift_spi")
        ],
        resources: [
            .copy("SequencesJS")
        ],
        plugins: plugins
    )
  ]
)
