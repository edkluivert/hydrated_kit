// hydrated_kit example: state that survives a relaunch.
//
//   dn run -d <ios-simulator-id>
//   dn run -d <android-emulator-id>
//
// Kill the app and open it again: the launch number goes up by one, the
// counter and the notes come back. "Forget everything" wipes the box, so the
// next launch starts from the initial states.

import 'package:dartnative/dartnative.dart';
import 'package:flutterbloc_kit/flutterbloc_kit.dart';
import 'package:hydrated_kit/hydrated_kit.dart';

import 'blocs.dart';
import 'dartnative_plugin_registrant.dart';

Future<void> main() async {
  DartNativePluginRegistrant.registerAll();
  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  // One call: builds the Hive-backed storage in the app-support directory
  // and installs it as HydratedBloc.storage.
  await initHydratedStorage(

  );
  runApp(const HydratedExampleApp());
}

const _ink = Color(0xFF16191F);
const _muted = Color(0xFF6B7280);
const _surface = Color(0xFFF3F4F6);
const _accent = Color(0xFF0F7A69);
const _danger = Color(0xFFD92D20);

class HydratedExampleApp extends StatelessWidget {
  const HydratedExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LaunchCubit>(lazy: false, create: (_) => LaunchCubit()),
        BlocProvider<CounterCubit>(create: (_) => CounterCubit()),
        BlocProvider<NotesBloc>(create: (_) => NotesBloc()),
      ],
      child: const App(title: 'hydrated_kit', home: HomeScreen()),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.light,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'hydrated_kit',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: const [
          _LaunchSection(),
          _CounterSection(),
          _NotesSection(),
          _StorageSection(),
        ],
      ),
    );
  }
}

class _LaunchSection extends StatelessWidget {
  const _LaunchSection();

  @override
  Widget build(BuildContext context) {
    final launches = context.watch<LaunchCubit>().state;
    return _Section(
      title: 'Launch #$launches',
      caption: 'HydratedCubit<int> that emits state + 1 when created',
      child: const Text(
        'Quit the app and open it again: this number comes back from disk '
        'and goes up by one.',
        style: TextStyle(color: _muted, fontSize: 15),
      ),
    );
  }
}

class _CounterSection extends StatelessWidget {
  const _CounterSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Counter',
      caption: 'HydratedCubit<int> · toJson / fromJson',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<CounterCubit, int>(
            builder: (context, count) => Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _accent,
                fontSize: 56,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Button(
                title: '−',
                variant: ButtonVariant.tinted,
                onPressed: () => context.read<CounterCubit>().decrement(),
              ),
              const SizedBox(width: 12),
              Button(
                title: '+',
                variant: ButtonVariant.filled,
                color: _accent,
                onPressed: () => context.read<CounterCubit>().increment(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Notes',
      caption: 'HydratedBloc with events · a list in the JSON',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<NotesBloc, NotesState>(
            builder: (context, state) {
              if (state.notes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No notes yet.',
                    style: TextStyle(color: _muted, fontSize: 15),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < state.notes.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.notes[i],
                            style: const TextStyle(color: _ink, fontSize: 15),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.trash,
                            color: _danger,
                            size: 18,
                          ),
                          onPressed: () =>
                              context.read<NotesBloc>().add(NoteRemoved(i)),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Button(
            title: 'Add note',
            variant: ButtonVariant.tinted,
            onPressed: () {
              final now = DateTime.now();
              final stamp =
                  '${now.hour.toString().padLeft(2, '0')}:'
                  '${now.minute.toString().padLeft(2, '0')}:'
                  '${now.second.toString().padLeft(2, '0')}';
              context.read<NotesBloc>().add(NoteAdded('Note at $stamp'));
            },
          ),
        ],
      ),
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Storage',
      caption: 'hydratedStorageDirectory() · application support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hydratedStorageDirectory().path,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Button(
            title: 'Forget everything',
            variant: ButtonVariant.tinted,
            color: _danger,
            onPressed: () async {
              // clear() removes the persisted entry; the in-memory state
              // stays until the next launch, as in hydrated_bloc on Flutter.
              await context.read<LaunchCubit>().clear();
              await context.read<CounterCubit>().clear();
              await context.read<NotesBloc>().clear();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cleared. Relaunch to start fresh.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
