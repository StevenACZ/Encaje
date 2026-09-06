// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Encaje",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Encaje", targets: ["EncajeApp"])],
  dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
  targets: [
    .target(name: "EncajeCore"),
    .executableTarget(
      name: "EncajeApp",
      dependencies: ["EncajeCore", .product(name: "Sparkle", package: "Sparkle")],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
      ]),
    .testTarget(name: "EncajeCoreTests", dependencies: ["EncajeCore"]),
    .testTarget(name: "EncajeAppTests", dependencies: ["EncajeApp"]),
  ]
)
