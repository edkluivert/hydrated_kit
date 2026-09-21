# hydrated_kit example

A launch counter, a counter and a notes list, all `HydratedCubit` /
`HydratedBloc`, that come back after the app is killed and reopened. The
"Forget everything" button clears the box so the next launch starts fresh.

```sh
dn run -d <ios-simulator-id>
```

The iOS project targets iOS 15.0 (the `dn create` template's 14.0 is below
what the dartnative_ios pod requires). `dartnative_path_provider` is listed
in this pubspec directly, which the app needs even though hydrated_kit
depends on it; see the package README.
