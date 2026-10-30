# Badge3D

Interactive, procedurally generated 3D badges for SwiftUI, built with SceneKit. Includes a small iOS playground for exploring materials, shapes, and spin animations.

## Features

- Gold, silver, and bronze finishes with generated environment lighting.
- Hexagonal and circular shapes with beveled edges and raised rims.
- SF Symbols rendered onto the badge face.
- Drag to rotate, flick with momentum, and spring back to the nearest face.
- Five introductory spin curves to compare in the demo.
- No external packages or bundled 3D models.

## Run the demo

Open `Badge3D.xcodeproj` in Xcode 16 or later, select the `Badge3D` scheme and an iPhone simulator, then run. The deployment target is iOS 17.0.

For a physical device, configure your own bundle identifier and development team and enable code signing in the target settings.

The repository includes an XcodeGen specification in `project.yml`. If you use XcodeGen, run `xcodegen generate` to regenerate the project.

## Use the badge in your app

Copy `Sources/Badge3DView.swift` into your iOS app target, then use it from SwiftUI:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Badge3DView(
            symbolName: "bolt.fill",
            style: .gold,
            shape: .hexagon,
            spin: .settle
        )
        .frame(width: 320, height: 320)
    }
}
```

Use `.silver` or `.bronze` for another finish, or create a `Badge3DStyle` with your own metal, shadow, and ink colors. The badge has a transparent background.

## Contributing

Issues and pull requests are welcome. Include reproduction steps for bugs and verify changes with an iOS simulator build.

## License

MIT. See [LICENSE](LICENSE).
