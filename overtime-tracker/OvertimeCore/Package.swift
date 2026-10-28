// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OvertimeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "OvertimeCore", targets: ["OvertimeCore"])],
    targets: [
        .target(name: "OvertimeCore", path: "Sources/OvertimeCore"),
        .testTarget(name: "OvertimeCoreTests", dependencies: ["OvertimeCore"], path: "Tests/OvertimeCoreTests")
    ]
)
