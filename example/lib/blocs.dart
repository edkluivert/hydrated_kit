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

class NotesBloc extends HydratedBloc<NotesEvent, NotesState> {
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
  NotesState? fromJson(Map<String, dynamic> json) {
    final notes = json['notes'];
    if (notes is! List) return null;
    return NotesState(notes.cast<String>());
  }

  @override
  Map<String, dynamic>? toJson(NotesState state) => {'notes': state.notes};
}
