import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'data/models/song_model.dart';
import 'data/models/audio_effects_model.dart';
import 'data/models/artist_model.dart';
import 'data/models/search_history_model.dart'; // Import SearchHistory Model
import 'presentation/controllers/audio_controller.dart';
import 'presentation/controllers/audio_effects_controller.dart';
import 'presentation/controllers/theme_controller.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(AudioEffectsAdapter());
  Hive.registerAdapter(ArtistAdapter());
  Hive.registerAdapter(SearchHistoryAdapter()); // Register SearchHistory Adapter

  // Open Hive boxes
  await Hive.openBox<Song>('songs');
  await Hive.openBox('settings');
  await Hive.openBox<AudioEffects>('audioEffects');
  await Hive.openBox<Artist>('artists');
  await Hive.openBox<SearchHistory>('search_history'); // Open SearchHistory Box

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
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
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        return MaterialApp.router(
          title: 'Audio X',
          theme: themeController.lightTheme,
          darkTheme: themeController.darkTheme,
          themeMode: themeController.themeMode,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(themeController.fontScale)),
              child: child!,
            );
          },
        );
      },
    );
  }
}
