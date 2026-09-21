# hydrated_kit

[hydrated_bloc](https://pub.dev/packages/hydrated_bloc) for
[DartNative](https://dartnative.com): persisted `Bloc` and `Cubit` state, set
up in one call.

<p align="center">
  <img src="https://raw.githubusercontent.com/edkluivert/hydrated_kit/main/doc/demo.gif" width="360" alt="hydrated_kit example: the counter is tapped and two notes added, the app is killed and reopened, and launch #2 shows the counter and notes back from disk" />
</p>

## Why

hydrated_bloc is pure Dart and runs on DartNative unchanged. The one thing a
Flutter app hands it that DartNative cannot is the directory for its Hive box,
which Flutter gets from `path_provider`. This package re-exports hydrated_bloc
and resolves that directory through `dartnative_path_provider`, so the
Flutter setup

```dart
HydratedBloc.storage = await HydratedStorage.build(
  storageDirectory: HydratedStorageDirectory(
    (await getApplicationSupportDirectory()).path,
  ),
);
```

becomes

```dart
await initHydratedStorage();
```

## Setup

```yaml
dependencies:
  hydrated_kit: ^0.1.0
  dartnative_path_provider: ^1.0.0
```

`dartnative_path_provider` must be listed by the app as well, even though
hydrated_kit depends on it: `dn pub get` wires a DartNative plugin's native
code and real Dart sources for the app's direct dependencies only. Without
the line the app compiles against the plugin's header stub and
`initHydratedStorage` throws `UnimplementedError` at launch.

## Usage

```dart
import 'package:dartnative/dartnative.dart';
import 'package:hydrated_kit/hydrated_kit.dart';

Future<void> main() async {
  DartNativePluginRegistrant.registerAll();
  await initHydratedStorage();
  runApp(const App(home: HomeScreen()));
}

class CounterCubit extends HydratedCubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);

  @override
  int? fromJson(Map<String, dynamic> json) => json['value'] as int?;

  @override
  Map<String, dynamic>? toJson(int state) => {'value': state};
}
```

`HydratedBloc`, `HydratedCubit`, `HydratedMixin`, `HydratedStorage`,
`HydratedAesCipher`, `Storage` and `package:bloc` all come from the re-export;
everything in the
[hydrated_bloc documentation](https://bloclibrary.dev/bloc-concepts/#hydratedbloc)
applies as written.

### Where the box lives

```dart
await initHydratedStorage(location: HydratedStorageLocation.applicationDocuments);
```

| `HydratedStorageLocation` | iOS                             | Android          |
| ------------------------- | ------------------------------- | ---------------- |
| `applicationSupport` (default) | `Library/Application Support` | app files dir    |
| `applicationDocuments`    | `Documents`                     | app files dir    |
| `applicationCache`        | `Library/Caches`                | cache dir        |
| `temporary`               | `tmp`                           | cache dir        |

The default is the app-support directory: not user-visible, not purged.
hydrated_bloc's Flutter README uses the temporary directory, where iOS may
delete the box between launches.

### Encryption

```dart
final key = sha256.convert(utf8.encode(password)).bytes;
await initHydratedStorage(encryptionCipher: HydratedAesCipher(key));
```

### The pieces

- `hydratedStorageDirectory([location])` returns the
  `HydratedStorageDirectory` for a location, synchronously.
- `buildHydratedStorage({location, encryptionCipher})` builds a
  `HydratedStorage` there without installing it.
- `initHydratedStorage({location, encryptionCipher})` builds it and sets
  `HydratedBloc.storage`. Returns the storage for `clear()` or `close()`.

## Example

`example/` is a launch counter, a counter and a notes list that all come back
after the app is killed and reopened, plus a button that clears the box. It
uses [flutterbloc_kit](https://dartpub.dev/packages/flutterbloc_kit) for the
widgets.

## License

MIT.
