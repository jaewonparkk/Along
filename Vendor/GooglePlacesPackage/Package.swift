// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "GooglePlaces",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "GooglePlaces", targets: ["GooglePlacesTarget"]),
        .library(name: "GooglePlacesSwift", targets: ["GooglePlacesSwiftTarget"]),
    ],
    targets: [
        .binaryTarget(
            name: "GooglePlaces",
            path: "Frameworks/GooglePlaces.xcframework"
        ),
        .target(
            name: "GooglePlacesTarget",
            dependencies: ["GooglePlaces"],
            path: "Places",
            sources: ["GMSEmpty.m"],
            resources: [.copy("Resources/GooglePlacesResources/GooglePlaces.bundle")],
            publicHeadersPath: "Sources",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreText"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Security"),
                .linkedFramework("UIKit"),
            ]
        ),
        .binaryTarget(
            name: "GooglePlacesSwift",
            path: "Frameworks/GooglePlacesSwift.xcframework"
        ),
        .target(
            name: "GooglePlacesSwiftTarget",
            dependencies: ["GooglePlacesSwift", "GooglePlacesTarget"],
            path: "PlacesSwift",
            sources: ["Empty.swift"],
            resources: [.copy("Resources/GooglePlacesSwiftResources/GooglePlacesSwift.bundle")],
            publicHeadersPath: "Sources"
        ),
    ]
)
