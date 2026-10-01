// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ByteRelay",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "ByteRelay", targets: ["RelayApp"]),
        .executable(name: "relay-diagnostics", targets: ["RelayDiagnostics"]),
        .executable(name: "relay-tunnel-runner", targets: ["TunnelRunner"]),
        .library(name: "RelayCore", targets: ["RelayCore"]),
    ],
    targets: [
        .target(name: "ProcessBridge", publicHeadersPath: "include"),
        .executableTarget(name: "TunnelRunner"),
        .target(name: "RelayCore", dependencies: ["ProcessBridge"]),
        .executableTarget(name: "RelayApp", dependencies: ["RelayCore"]),
        .executableTarget(name: "RelayDiagnostics", dependencies: ["RelayCore"]),
        .testTarget(name: "RelayCoreTests", dependencies: ["RelayCore"]),
    ]
)
