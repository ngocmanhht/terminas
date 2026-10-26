// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Terminas",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Terminas", targets: ["Terminas"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Terminas",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Terminas"
        ),
        .testTarget(
            name: "TerminasTests",
            dependencies: ["Terminas"],
            path: "Tests/TerminasTests"
        ),
    ]
)
