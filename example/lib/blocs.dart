// Persisted state holders. Nothing here imports dartnative: HydratedBloc and
// HydratedCubit are pure Dart and serialise through toJson / fromJson.

import 'package:hydrated_kit/hydrated_kit.dart';

/// Counts launches: every construction emits state + 1, so the number on
/// screen is proof of hydration without touching anything.
class LaunchCubit extends HydratedCubit<int> {
  LaunchCubit() : super(0) {
    emit(state + 1);
  }

  @override
  int? fromJson(Map<String, dynamic> json) => json['launches'] as int?;

  @override
  Map<String, dynamic>? toJson(int state) => {'launches': state};
}

class CounterCubit extends HydratedCubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

  @override
  int? fromJson(Map<String, dynamic> json) => json['value'] as int?;

  @override
  Map<String, dynamic>? toJson(int state) => {'value': state};
}

sealed class NotesEvent {
  const NotesEvent();
}

class NoteAdded extends NotesEvent {
  const NoteAdded(this.text);
  final String text;
}

class NoteRemoved extends NotesEvent {
  const NoteRemoved(this.index);
  final int index;
}

class NotesCleared extends NotesEvent {
  const NotesCleared();
}

class NotesState {
  const NotesState(this.notes);
  final List<String> notes;
}

/// Versioned: notes were first persisted as `{'notes': [...]}` with no
/// version at all, so a 0.1.x install migrates from version 0 the first time
/// this build runs, then writes `{'notes': [...], '__schemaVersion': 1}`.
class NotesBloc extends HydratedBloc<NotesEvent, NotesState>
    with VersionedHydration<NotesState> {
  NotesBloc() : super(const NotesState([])) {
    on<NoteAdded>((event, emit) {
      emit(NotesState([...state.notes, event.text]));
    });
    on<NoteRemoved>((event, emit) {
      final notes = [...state.notes]..removeAt(event.index);
      emit(NotesState(notes));
    });
    on<NotesCleared>((event, emit) => emit(const NotesState([])));
  }

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic>? migrate(int from, Map<String, dynamic> json) =>
      json; // the unversioned blob already has the version-1 shape

  @override
  NotesState? fromCurrentJson(Map<String, dynamic> json) {
    final notes = json['notes'];
    if (notes is! List) return null;
    return NotesState(notes.cast<String>());
  }

  @override
  Map<String, dynamic>? toCurrentJson(NotesState state) =>
      {'notes': state.notes};
}
