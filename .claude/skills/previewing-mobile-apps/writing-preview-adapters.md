# Writing preview adapters

A preview runs the app's code but cannot run native code: a package that talks
to a real camera, a map renderer, a Bluetooth stack. When the app imports one,
the engine refuses with a diagnostic that is also the work order:

```json
{
  "ok": false,
  "code": "PREVIEW_UNSUPPORTED_MODULE",
  "module": "react-native-image-picker",
  "importedBy": "src/screens/Profile.tsx",
  "mockPath": ".mobai/preview/rn/mocks/react-native-image-picker.ts",
  "suggestion": "write an adapter at mockPath"
}
```

The envelope carries every module found in one pass under `modules`, each
with its own `mockPath`: write them all before running again. An entry with
`missingFile: true` (React Native) is a relative import of a file the project
does not have; put the file under `mocks/` at the same aliased path, or fix
the import.

Before writing one, check the catalogue of ready adapters at
https://github.com/MobAI-App/mobai-dev/tree/main/adapters; common packages
are already covered and a catalogue file drops in unchanged.

Write a small file at `mockPath` that presents the package's API and implements
it with the preview's primitives. The engine substitutes it for the real
package in the preview build only. The app's production source is NEVER edited,
and the adapter lives with the project, written once.

Implement only the surface the app uses. On SwiftUI the diagnostic includes
`symbols`, the identifiers the refusing file actually referenced; cover those
and stop.

## Where adapters go, per framework

| framework | path | language | mechanism |
|---|---|---|---|
| Flutter | `.mobai/preview/flutter/mocks/<plugin>.dart` | Dart | replaces the plugin package in the preview build |
| React Native | `.mobai/preview/rn/mocks/<package>.ts` | TypeScript | aliased over the package; deep imports use nested paths like `mocks/react-native/Libraries/...` |
| SwiftUI | `.mobai/preview/swiftui/mocks/<Module>.swift` | Swift | becomes a module named `<Module>`, so the screen's `import` resolves to it |

A newly written adapter is picked up on the next `preview run` or
`preview reload`; deleting it restores the refusal.

## The primitives

The same names exist in every engine, in its own language. Import
`mobai-preview` (TypeScript), `package:preview_bridge/mobai_preview.dart`
(Dart), or `MobAIPreview` (Swift).

```
location.current()            the scenario's fix, or null
permissions.status(name)      granted | denied | prompt
permissions.request(name)     resolves a prompt; async
camera.pickImage()            the scenario's camera fixture; async
photos.pickImage()            the scenario's photos fixture; async
auth.currentUser()            the scenario's user, or null
notifications.next()          the pending push; consumes it
clipboard.get() / set(text)
deepLink.initial() / next()
subscribe(listener)           called on every live mock change
```

Network needs no adapter: the engine intercepts the app's own HTTP calls.

## Worked examples

**React Native**, an image picker:

```ts
// .mobai/preview/rn/mocks/react-native-image-picker.ts
import { camera, permissions } from 'mobai-preview';

export async function launchCamera() {
  await permissions.request('camera');
  const image = await camera.pickImage();
  return { assets: image ? [{ uri: image.uri }] : [], didCancel: !image };
}
```

**SwiftUI**, a place card from a third-party package (Apple's own MapKit and
Charts need no adapter: the engine draws them), and the one rule Swift
adapters must know: read the mocked world in a default argument, not inside
`body`. A view with no stored
properties never changes value, so the graph never re-evaluates it, and an
adapter that reads the world in `body` shows the first answer forever while
the rest of the screen updates.

```swift
// .mobai/preview/swiftui/mocks/PlacesKit.swift
import SwiftUI
import MobAIPreview

public struct MapSnapshot: View {
    private let place: String
    public init(place: String = MapSnapshot.currentPlaceName()) {
        self.place = place
    }
    public static func currentPlaceName() -> String {
        location.current()?.label ?? "nowhere"
    }
    public var body: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.82, green: 0.86, blue: 0.80)).frame(height: 120.0)
            Text("map of \(place)")
        }
    }
}
```

**Flutter**, a camera plugin:

```dart
// .mobai/preview/flutter/mocks/fake_camera.dart
import 'package:preview_bridge/mobai_preview.dart';

Future<String> takePicture() async {
  await MobAIPreview.permissions.request('camera');
  final image = await MobAIPreview.camera.pickImage();
  return image?.fileName ?? 'no-image';
}
```

## Judgement calls

- **A placeholder is enough.** The adapter exists so the surrounding screen and
  state logic can be built; it does not reproduce the native experience. A map
  adapter that renders a rectangle with the place name is a good adapter.
- **Only native packages need one.** On React Native the engine resolves
  path aliases, `require()`, CommonJS, JSX in `.js` and `process.env` itself;
  a specifier the envelope lists under `modules` is a package to adapt or a
  file the project is missing, never a reason to write an alias shim. A
  React Native adapter replaces the package for the app's own imports; a
  library that imports the same package keeps the real one unless the
  adapter's first lines carry `@mobai-deep`.
- **Some things are not adapters.** On Flutter, a channel the app opens to
  its own AppDelegate is stubbed from the preview entry
  (`.mobai/preview/flutter/preview_main.dart`, `PreviewChannels.stub`), and
  an adapter added while the engine runs needs a restart.
- **The compiler is on your side.** A broken adapter fails with
  `PREVIEW_COMPILE_FAILED` carrying the exact compiler errors; fix and rerun.
- **SwiftUI network edge**: `URLSession.shared` is intercepted automatically.
  A session built from its own configuration opts in with one line,
  `PreviewURLProtocol.enable(in: config)`, in the adapter or preview-only code.
- Native behaviour still needs native verification eventually; the adapter
  buys the whole UI and flow iteration before that.
