/// hydrated_bloc for DartNative.
///
/// [hydrated_bloc](https://pub.dev/packages/hydrated_bloc) is pure Dart and
/// runs on DartNative unchanged; what a Flutter app supplies from
/// `path_provider` is the directory its Hive box lives in. This package
/// re-exports hydrated_bloc and resolves that directory through
/// `dartnative_path_provider`, so setup is one line:
///
/// ```dart
/// import 'package:dartnative/dartnative.dart';
/// import 'package:hydrated_kit/hydrated_kit.dart';
///
/// Future<void> main() async {
///   DartNativePluginRegistrant.registerAll();
///   await initHydratedStorage();
///   runApp(const App());
/// }
///
/// class CounterCubit extends HydratedCubit<int> {
///   CounterCubit() : super(0);
///   void increment() => emit(state + 1);
///
///   @override
///   int? fromJson(Map<String, dynamic> json) => json['value'] as int?;
///
///   @override
///   Map<String, dynamic>? toJson(int state) => {'value': state};
/// }
/// ```
///
/// `HydratedBloc`, `HydratedCubit`, `HydratedMixin`, `HydratedStorage`,
/// `HydratedAesCipher` and `package:bloc` come from the re-export.
///
/// Mix in [VersionedHydration] to store a schema version with the state and
/// get a `migrate(from, json)` hook when the shape changes between releases.
library;

import 'package:dartnative_path_provider/dartnative_path_provider.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

export 'package:hydrated_bloc/hydrated_bloc.dart';
export 'src/versioned_hydration.dart';

/// Where on the device the hydrated Hive box is kept.
enum HydratedStorageLocation {
  /// App-support files the user never sees and the OS does not purge:
  /// `Library/Application Support` on iOS, the app's files dir on Android.
  /// The default, and the right choice for state that must survive.
  applicationSupport,

  /// User documents; backed up, and on iOS visible in the Files app when the
  /// app opts in. Use when the persisted state is the user's own data.
  applicationDocuments,

  /// Cache files the OS may purge under storage pressure. Use for state that
  /// is cheap to rebuild.
  applicationCache,

  /// Transient files. Flutter's hydrated_bloc README uses this; state can be
  /// lost between launches.
  temporary,
}

/// The [HydratedStorageDirectory] for [location], resolved synchronously
/// through dartnative_path_provider.
HydratedStorageDirectory hydratedStorageDirectory([
  HydratedStorageLocation location = HydratedStorageLocation.applicationSupport,
]) {
  final path = switch (location) {
    HydratedStorageLocation.applicationSupport =>
      getApplicationSupportDirectory(),
    HydratedStorageLocation.applicationDocuments =>
      getApplicationDocumentsDirectory(),
    HydratedStorageLocation.applicationCache => getApplicationCacheDirectory(),
    HydratedStorageLocation.temporary => getTemporaryDirectory(),
  };
  return HydratedStorageDirectory(path);
}

/// Builds a [HydratedStorage] in [location], the DartNative counterpart of
///
/// ```dart
/// HydratedStorage.build(
///   storageDirectory: HydratedStorageDirectory(
///     (await getApplicationSupportDirectory()).path,
///   ),
/// )
/// ```
///
/// Pass [encryptionCipher] (for example a [HydratedAesCipher]) to encrypt the
/// box. Does not assign [HydratedBloc.storage]; see [initHydratedStorage].
Future<HydratedStorage> buildHydratedStorage({
  HydratedStorageLocation location = HydratedStorageLocation.applicationSupport,
  HydratedCipher? encryptionCipher,
}) {
  return HydratedStorage.build(
    storageDirectory: hydratedStorageDirectory(location),
    encryptionCipher: encryptionCipher,
  );
}

/// Builds the storage with [buildHydratedStorage] and installs it as
/// [HydratedBloc.storage], so every `HydratedBloc` and `HydratedCubit`
/// created afterwards hydrates from it. Call once in `main`, before `runApp`.
///
/// Returns the storage, for `clear()` or `close()` later.
Future<HydratedStorage> initHydratedStorage({
  HydratedStorageLocation location = HydratedStorageLocation.applicationSupport,
  HydratedCipher? encryptionCipher,
}) async {
  final storage = await buildHydratedStorage(
    location: location,
    encryptionCipher: encryptionCipher,
  );
  HydratedBloc.storage = storage;
  return storage;
}
