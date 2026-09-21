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

## Other storage backends

hydrated_bloc persists through its `Storage` interface, and `HydratedStorage`
(the Hive box `initHydratedStorage` sets up) is only the default. Anything
that implements the five methods can hold bloc state:

```dart
abstract class Storage {
  dynamic read(String key);                     // synchronous
  Future<void> write(String key, dynamic value);
  Future<void> delete(String key);
  Future<void> clear();
  Future<void> close();
}
```

Install a backend for every bloc:

```dart
HydratedBloc.storage = await PreferencesStorage.build();
```

or for one bloc, so an auth cubit can live in the keychain while settings sit
in preferences (hydrated_bloc 11):

```dart
class AuthCubit extends HydratedCubit<AuthState> {
  AuthCubit({required Storage storage}) : super(const AuthState(), storage: storage);
  ...
}

AuthCubit(storage: await SecureHydratedStorage.build());
```

Two rules hold for every backend. `write` receives whatever `toJson` returned,
so the value must survive a JSON round trip. And a bloc's whole state is one
entry under its storage token, so a large state is rewritten on every emit.

The recipes below are complete and compile against the DartNative plugins;
copy the one you need into your app. They are not part of this package
because each would force every app to add that plugin as a direct
dependency, for the same reason `dartnative_path_provider` has to be listed
(see Setup).

### Shared preferences

`dartnative_shared_preferences` stores strings, so the state is JSON-encoded.
Reads are synchronous on DartNative, which fits `Storage.read` as is.

```dart
import 'dart:convert';

import 'package:dartnative_shared_preferences/dartnative_shared_preferences.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// hydrated_bloc [Storage] on SharedPreferences: each bloc's state is one
/// JSON string under its storage token.
class PreferencesStorage implements Storage {
  PreferencesStorage._(this._prefs);

  static Future<PreferencesStorage> build() async =>
      PreferencesStorage._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  dynamic read(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> write(String key, dynamic value) =>
      _prefs.setString(key, jsonEncode(value));

  @override
  Future<void> delete(String key) => _prefs.remove(key);

  @override
  Future<void> clear() => _prefs.clear();

  @override
  Future<void> close() async {}
}
```

### Secure storage

`dartnative_secure_storage` is the keychain on iOS and the keystore on
Android: the right place for tokens and anything personal. Its reads are
asynchronous while `Storage.read` is not, so the adapter loads every entry
once at `build` and writes through, keeping the in-memory copy current.

```dart
import 'dart:convert';

import 'package:dartnative_secure_storage/dartnative_secure_storage.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// hydrated_bloc [Storage] on the keychain / keystore. Keychain reads are
/// asynchronous and [Storage.read] is not, so [build] loads everything once
/// and [write] keeps the in-memory copy current.
class SecureHydratedStorage implements Storage {
  SecureHydratedStorage._(this._secure, this._cache);

  static Future<SecureHydratedStorage> build({
    SecureStorage secure = const SecureStorage(),
  }) async {
    final all = await secure.readAll();
    return SecureHydratedStorage._(secure, {
      for (final entry in all.entries) entry.key: jsonDecode(entry.value),
    });
  }

  final SecureStorage _secure;
  final Map<String, dynamic> _cache;

  @override
  dynamic read(String key) => _cache[key];

  @override
  Future<void> write(String key, dynamic value) {
    _cache[key] = value;
    return _secure.write(key: key, value: jsonEncode(value));
  }

  @override
  Future<void> delete(String key) {
    _cache.remove(key);
    return _secure.delete(key: key);
  }

  @override
  Future<void> clear() {
    _cache.clear();
    return _secure.deleteAll();
  }

  @override
  Future<void> close() async {}
}
```

### A Hive box the app already has

`dartnative_hive` is the same hive_ce that `HydratedStorage` uses. Use this
when the app opens its own boxes and wants bloc state in one of them, or in
a box with a custom name, path or type adapters. Hive stores maps natively,
so nothing is encoded.

```dart
import 'package:dartnative_hive/dartnative_hive.dart';
import 'package:dartnative_path_provider/dartnative_path_provider.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// hydrated_bloc [Storage] on a Hive box the app already opens. Hive stores
/// maps natively, so nothing is encoded.
class HiveBoxStorage implements Storage {
  HiveBoxStorage(this._box);

  static Future<HiveBoxStorage> build({String boxName = 'bloc_state'}) async {
    Hive.initDartNative(getApplicationSupportDirectory(), subDir: 'hive');
    return HiveBoxStorage(await Hive.openBox<dynamic>(boxName));
  }

  final Box<dynamic> _box;

  @override
  dynamic read(String key) => _box.get(key);

  @override
  Future<void> write(String key, dynamic value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> clear() => _box.clear();

  @override
  Future<void> close() => _box.close();
}
```

## Example

`example/` is a launch counter, a counter and a notes list that all come back
after the app is killed and reopened, plus a button that clears the box. It
uses [flutterbloc_kit](https://dartpub.dev/packages/flutterbloc_kit) for the
widgets.

## License

MIT.
