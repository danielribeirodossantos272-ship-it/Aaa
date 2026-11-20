// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FLEXReplica",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FLEXReplicaCore", type: .dynamic, targets: ["FLEXReplicaCore"]),
        .executable(name: "FLEXReplicaDemo", targets: ["FLEXReplicaDemo"])
    ],
    targets: [
        .target(name: "FLEXReplicaAutoOpen", publicHeadersPath: "include"),
        .target(name: "FLEXReplicaRuntimeBridge", publicHeadersPath: "include"),
        .target(name: "FLEXReplicaCore", dependencies: ["FLEXReplicaAutoOpen", "FLEXReplicaRuntimeBridge"]),
        .executableTarget(name: "FLEXReplicaDemo", dependencies: ["FLEXReplicaCore"]),
        .testTarget(name: "FLEXReplicaCoreTests", dependencies: ["FLEXReplicaCore"])
    ]
)
