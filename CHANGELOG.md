## 0.2.0

- `VersionedHydration<State>`: a mixin for `HydratedBloc` and
  `HydratedCubit` that persists a `schemaVersion` next to the state and
  calls `migrate(from, json)` when a build reads state written by an older
  one. State stored before adopting the mixin migrates from version `0`;
  `null` from `migrate` starts from the initial state.
- `HydratedSchemaDowngrade`, thrown into `onHydrationError` when the stored
  version is ahead of the build, so `overwrite` and `retain` apply as usual.
- Implement `fromCurrentJson` and `toCurrentJson` instead of `fromJson` and
  `toJson` when using the mixin.

## 0.1.1

Initial release.

- Re-exports hydrated_bloc 11 (pure Dart, unchanged).
- `hydratedStorageDirectory`, `buildHydratedStorage` and
  `initHydratedStorage` resolve the box directory through
  `dartnative_path_provider`; `HydratedStorageLocation` picks app support
  (default), documents, cache or temporary.
- Verified on the iOS simulator: launch count, counter and notes survive a
  hot restart and a relaunch; demo in `doc/`.
