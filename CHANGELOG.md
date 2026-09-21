## 0.1.1

Initial release.

- Re-exports hydrated_bloc 11 (pure Dart, unchanged).
- `hydratedStorageDirectory`, `buildHydratedStorage` and
  `initHydratedStorage` resolve the box directory through
  `dartnative_path_provider`; `HydratedStorageLocation` picks app support
  (default), documents, cache or temporary.
- Verified on the iOS simulator: launch count, counter and notes survive a
  hot restart and a relaunch; demo in `doc/`.
