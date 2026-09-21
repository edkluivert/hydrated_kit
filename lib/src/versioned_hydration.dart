import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:meta/meta.dart';

/// Thrown during hydration when the stored state was written by a build with
/// a higher [VersionedHydration.schemaVersion] than this one: the user
/// rolled the app back, or a beta wrote state a release cannot read.
///
/// Reaches the bloc's `onHydrationError` callback like any other hydration
/// failure. The default behaviour, [HydrationErrorBehavior.overwrite],
/// starts from the initial state and replaces the newer blob on the next
/// emit; return [HydrationErrorBehavior.retain] to keep the newer blob on
/// disk until the app is upgraded again.
class HydratedSchemaDowngrade implements Exception {
  const HydratedSchemaDowngrade({
    required this.storageToken,
    required this.stored,
    required this.current,
  });

  /// The storage key the blob was read from.
  final String storageToken;

  /// The schema version the blob was written with.
  final int stored;

  /// The schema version this build knows.
  final int current;

  @override
  String toString() =>
      'HydratedSchemaDowngrade: $storageToken was stored at schema version '
      '$stored but this build reads version $current';
}

/// Versioned persistence for a [HydratedBloc] or [HydratedCubit]: the state
/// is stored with a schema version, and a [migrate] hook runs when the
/// stored version is behind the one this build writes.
///
/// ```dart
/// class SettingsCubit extends HydratedCubit<Settings>
///     with VersionedHydration<Settings> {
///   SettingsCubit() : super(Settings.defaults);
///
///   @override
///   int get schemaVersion => 3;
///
///   @override
///   Map<String, dynamic>? migrate(int from, Map<String, dynamic> json) {
///     var out = json;
///     // v1 stored a bare theme string; v2 nested it under `appearance`.
///     if (from < 2) out = {...out, 'appearance': {'theme': out['theme']}};
///     // v3 renamed `appearance` to `display`.
///     if (from < 3) out = {...out, 'display': out['appearance']};
///     return out;
///   }
///
///   @override
///   Settings? fromCurrentJson(Map<String, dynamic> json) =>
///       Settings.fromJson(json);
///
///   @override
///   Map<String, dynamic>? toCurrentJson(Settings state) => state.toJson();
/// }
/// ```
///
/// On hydration the stored version is compared with [schemaVersion]:
///
/// - **Equal**: [fromCurrentJson] runs on the stored map.
/// - **Behind**: [migrate] is called once with the stored version and map,
///   and its result goes to [fromCurrentJson]. Return `null` to discard the
///   old state and start from the initial state instead.
/// - **No version at all** (state persisted before this mixin was adopted):
///   treated as version `0`, so `migrate(0, json)` is where an already
///   shipped app upgrades its first unversioned blob.
/// - **Ahead**: a [HydratedSchemaDowngrade] is thrown and handled by the
///   bloc's `onHydrationError`.
///
/// Every write stores [schemaVersion] alongside the map from [toCurrentJson]
/// under [schemaVersionKey], and a migrated state is re-persisted in the new
/// shape as soon as the bloc hydrates, so a migration runs once per install.
///
/// [fromJson] and [toJson] are implemented by the mixin and must not be
/// overridden; implement [fromCurrentJson] and [toCurrentJson] instead.
mixin VersionedHydration<State> on HydratedMixin<State> {
  /// The schema version this build writes. Must be at least `1`; `0` is
  /// reserved for state stored before versioning. Bump it whenever the map
  /// from [toCurrentJson] changes shape, and handle the jump in [migrate].
  int get schemaVersion;

  /// The key the version is stored under, next to the state's own fields.
  /// Change it only if your state already uses the default name.
  String get schemaVersionKey => '__schemaVersion';

  /// Upgrades a map stored at version [from] (always below [schemaVersion])
  /// to the current shape. [json] is the stored map with [schemaVersionKey]
  /// already removed.
  ///
  /// Return the upgraded map, or `null` to drop the stored state and start
  /// from the initial state. The default drops it.
  Map<String, dynamic>? migrate(int from, Map<String, dynamic> json) => null;

  /// Builds the state from a map in the current schema. Return `null` to
  /// fall back to the initial state, as with `HydratedMixin.fromJson`.
  State? fromCurrentJson(Map<String, dynamic> json);

  /// Serialises the state in the current schema. Return `null` to skip
  /// persisting it, as with `HydratedMixin.toJson`.
  Map<String, dynamic>? toCurrentJson(State state);

  @override
  @nonVirtual
  State? fromJson(Map<String, dynamic> json) {
    assert(schemaVersion >= 1, 'schemaVersion must be at least 1');
    final stored = _storedVersion(json[schemaVersionKey]);
    final body = Map<String, dynamic>.of(json)..remove(schemaVersionKey);
    if (stored > schemaVersion) {
      throw HydratedSchemaDowngrade(
        storageToken: storageToken,
        stored: stored,
        current: schemaVersion,
      );
    }
    final current = stored == schemaVersion ? body : migrate(stored, body);
    if (current == null) return null;
    return fromCurrentJson(current);
  }

  @override
  @nonVirtual
  Map<String, dynamic>? toJson(State state) {
    assert(schemaVersion >= 1, 'schemaVersion must be at least 1');
    final body = toCurrentJson(state);
    if (body == null) return null;
    return {...body, schemaVersionKey: schemaVersion};
  }

  static int _storedVersion(Object? value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        _ => 0,
      };
}
