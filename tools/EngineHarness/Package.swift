// swift-tools-version: 5.9
import PackageDescription

/// Harness de linha de comando que roda o MESMO `RoomEngine` do app tvOS contra o emulador do
/// Firebase, para conferir as regras da secao 11 ponta a ponta sem depender de apertar botao no
/// Siri Remote. Reaproveita os arquivos de `tvos-app/Sources/Shared` por link simbolico.
let package = Package(
    name: "EngineHarness",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EngineHarness",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
