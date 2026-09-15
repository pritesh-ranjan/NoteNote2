// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteNote",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NoteNote",
            targets: ["NoteNoteApp"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NoteNoteApp",
            dependencies: [],
            path: "Sources/NoteNoteApp"
        )
    ]
)
