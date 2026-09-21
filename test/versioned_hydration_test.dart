import 'package:hydrated_kit/hydrated_kit.dart';
import 'package:test/test.dart';

class MemoryStorage implements Storage {
  final Map<String, dynamic> data = {};

  @override
  dynamic read(String key) => data[key];

  @override
  Future<void> write(String key, dynamic value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> close() async {}
}

/// Version 2 stores `{'count': n}`; version 1 stored `{'value': n}`; the
/// unversioned blob from before adoption stored `{'n': n}`.
class CounterCubit extends HydratedCubit<int> with VersionedHydration<int> {
  CounterCubit({super.onHydrationError}) : super(0);

  final migrations = <(int, Map<String, dynamic>)>[];

  @override
  int get schemaVersion => 2;

  @override
  Map<String, dynamic>? migrate(int from, Map<String, dynamic> json) {
    migrations.add((from, json));
    var out = json;
    if (from < 1) out = {'value': out['n']};
    if (from < 2) out = {'count': out['value']};
    return out;
  }

  @override
  int? fromCurrentJson(Map<String, dynamic> json) => json['count'] as int?;

  @override
  Map<String, dynamic>? toCurrentJson(int state) => {'count': state};

  void increment() => emit(state + 1);
}

class DroppingCubit extends HydratedCubit<int> with VersionedHydration<int> {
  DroppingCubit() : super(0);

  @override
  int get schemaVersion => 2;

  @override
  int? fromCurrentJson(Map<String, dynamic> json) => json['count'] as int?;

  @override
  Map<String, dynamic>? toCurrentJson(int state) => {'count': state};

  void increment() => emit(state + 1);
}

void main() {
  late MemoryStorage storage;
  const token = 'CounterCubit';

  setUp(() {
    storage = MemoryStorage();
    HydratedBloc.storage = storage;
  });

  test('a fresh bloc starts from the initial state and writes the version',
      () async {
    final cubit = CounterCubit();
    expect(cubit.state, 0);
    expect(cubit.migrations, isEmpty);
    cubit.increment();
    await Future<void>.delayed(Duration.zero);
    expect(storage.data[token], {'count': 1, '__schemaVersion': 2});
  });

  test('state at the current version hydrates without migrating', () {
    storage.data[token] = {'count': 7, '__schemaVersion': 2};
    final cubit = CounterCubit();
    expect(cubit.state, 7);
    expect(cubit.migrations, isEmpty);
  });

  test('older state is migrated once, with the version key stripped',
      () async {
    storage.data[token] = {'value': 4, '__schemaVersion': 1};
    final cubit = CounterCubit();
    expect(cubit.state, 4);
    expect(cubit.migrations, hasLength(1));
    expect(cubit.migrations.single.$1, 1);
    expect(cubit.migrations.single.$2, {'value': 4});
    await Future<void>.delayed(Duration.zero);
    expect(
      storage.data[token],
      {'count': 4, '__schemaVersion': 2},
      reason: 'hydrate re-persists the migrated state in the new shape',
    );
  });

  test('state stored before versioning is migrated from version 0', () {
    storage.data[token] = {'n': 9};
    final cubit = CounterCubit();
    expect(cubit.state, 9);
    expect(cubit.migrations, hasLength(1));
    expect(cubit.migrations.single.$1, 0);
    expect(cubit.migrations.single.$2, {'n': 9});
  });

  test('a migrate that returns null falls back to the initial state',
      () async {
    storage.data['DroppingCubit'] = {'count': 5, '__schemaVersion': 1};
    final cubit = DroppingCubit();
    expect(cubit.state, 0);
    cubit.increment();
    await Future<void>.delayed(Duration.zero);
    expect(storage.data['DroppingCubit'], {'count': 1, '__schemaVersion': 2});
  });

  test('a newer stored version raises HydratedSchemaDowngrade', () {
    storage.data[token] = {'count': 3, '__schemaVersion': 3};
    Object? seen;
    final cubit = CounterCubit(
      onHydrationError: (error, _) {
        seen = error;
        return HydrationErrorBehavior.overwrite;
      },
    );
    expect(cubit.state, 0);
    expect(
      seen,
      isA<HydratedSchemaDowngrade>()
          .having((e) => e.stored, 'stored', 3)
          .having((e) => e.current, 'current', 2)
          .having((e) => e.storageToken, 'storageToken', token),
    );
  });

  test('retain keeps the newer blob on disk after a downgrade', () async {
    final newer = {'count': 3, '__schemaVersion': 3};
    storage.data[token] = Map<String, dynamic>.of(newer);
    final cubit = CounterCubit(
      onHydrationError: (_, _) => HydrationErrorBehavior.retain,
    );
    cubit.increment();
    await Future<void>.delayed(Duration.zero);
    expect(storage.data[token], newer);
  });

  test('the default onHydrationError overwrites the newer blob on emit',
      () async {
    storage.data[token] = {'count': 3, '__schemaVersion': 3};
    final cubit = CounterCubit();
    cubit.increment();
    await Future<void>.delayed(Duration.zero);
    expect(storage.data[token], {'count': 1, '__schemaVersion': 2});
  });
}
