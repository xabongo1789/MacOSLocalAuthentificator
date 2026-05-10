// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalAuthenticator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LocalAuthenticator", targets: ["LocalAuthenticator"])
    ],
    targets: [
        .executableTarget(
            name: "LocalAuthenticator",
            path: "Sources/LocalAuthenticator"
        ),
        .testTarget(
            name: "LocalAuthenticatorTests",
            dependencies: ["LocalAuthenticator"],
            path: "Tests/LocalAuthenticatorTests"
        )
    ]
)
