// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FLEXReplica",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FLEXReplicaCore", targets: ["FLEXReplicaCore"]),
        .executable(name: "FLEXReplicaDemo", targets: ["FLEXReplicaDemo"])
    ],
    targets: [
        .target(name: "FLEXReplicaCore"),
        .executableTarget(name: "FLEXReplicaDemo", dependencies: ["FLEXReplicaCore"]),
        .testTarget(name: "FLEXReplicaCoreTests", dependencies: ["FLEXReplicaCore"])
    ]
)
