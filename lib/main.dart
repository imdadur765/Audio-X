import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'data/models/song_model.dart';
import 'data/models/audio_effects_model.dart';
import 'presentation/controllers/audio_controller.dart';
import 'presentation/controllers/audio_effects_controller.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(AudioEffectsAdapter());

  // Open Hive boxes
  await Hive.openBox<Song>('songs');
  await Hive.openBox('settings');
  await Hive.openBox<AudioEffects>('audioEffects');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(
          create: (_) {
            final controller = AudioEffectsController();
            // Initialize asynchronously after creation
            Future.microtask(() => controller.initialize());
            return controller;
          },
        ),
      ],
      child: const AudioXApp(),
    ),
  );
}

class AudioXApp extends StatelessWidget {
  const AudioXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio X',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomePage(),
    );
  }
}
