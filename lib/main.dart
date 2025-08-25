// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
// sqflite desktop compatibility
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'generated/l10n.dart';
import 'screens/splash_screen.dart';
import 'services/download_manager.dart';
import 'services/file_storage.dart';
import 'services/library.dart';
import 'services/lyrics.dart';
import 'services/media_player.dart';
import 'services/settings_manager.dart';
import 'themes/colors.dart';
import 'themes/dark.dart';
import 'themes/light.dart';
import 'utils/router.dart';
import 'ytmusic/ytmusic.dart';
import 'services/music_library_provider.dart';

Future<void> initializeApp() async {
  try {
    // Initialize core Flutter bindings first
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // Delay first frame until critical initialization is done
    binding.deferFirstFrame();

    // Start platform-specific initialization immediately
    final platformInitFuture = Platform.isAndroid
        ? JustAudioBackground.init(
            androidNotificationChannelId: 'com.jhelum.are.audio',
            androidNotificationChannelName: 'Audio playback',
            androidNotificationOngoing: true,
          ).then((_) {
            print('Audio background initialized');
            return null;
          })
        : Future<void>.value();

    // Initialize essential services in parallel
    await Future.wait([
      // Initialize storage system with high priority
      Future(() async {
        try {
          await initialiseHive();
          print('Hive initialized');
        } catch (e) {
          print('Hive init error: $e');
        }
      }),

      // Platform-specific init
      platformInitFuture,

      // Pre-warm critical services
      Future(() async {
        try {
          await SystemChannels.platform
              .invokeMethod<void>('SystemNavigator.systemReady');
        } catch (e) {
          // Silently handle any errors during pre-warming
        }
      }),

      // Add a small delay to ensure animations are smooth
      Future.delayed(const Duration(milliseconds: 100)),
    ]);

    // Initialize storage after Hive
    await FileStorage.initialise();
    print('FileStorage initialized');

    // Initialize sqflite for desktop platforms so databaseFactory is set
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        print('sqflite_common_ffi initialized for desktop');
      } catch (e) {
        print('Warning: sqflite_common_ffi init failed: $e');
      }
    }

    // Register SettingsManager (dependencies need this)
    final settingsManager = SettingsManager();
    GetIt.I.registerSingleton<SettingsManager>(settingsManager);
    print('SettingsManager registered');

    // Allow first frame to be rendered
    binding.allowFirstFrame();
  } catch (e) {
    print('Error during initialization: $e');
    rethrow;
  }
}

Future<void> initializeDesktopFeatures() async {
  if (Platform.isWindows) {
    await Future.delayed(Duration(milliseconds: 100));
    await Window.initialize();
    await Window.hideWindowControls();
    await WindowManager.instance.ensureInitialized();

    await windowManager.waitUntilReadyToShow();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    WindowEffect windowEffect = windowEffectList.firstWhere(
      (el) =>
          el.name.toUpperCase() ==
          Hive.box('SETTINGS').get(
            'WINDOW_EFFECT',
            defaultValue: WindowEffect.mica.name.toUpperCase(),
          ),
    );
    await Window.setEffect(
      effect: windowEffect,
      dark: getInitialDarkness(),
    );

    await windowManager.show();
    // allow the window to close immediately; the app will handle cleanup
    await windowManager.setPreventClose(false);
    await windowManager.setSkipTaskbar(false);
  }
}

void main() async {
  try {
    // Core initialization
    await initializeApp();

    // Platform-specific initialization
    if (Platform.isWindows) {
      await initializeDesktopFeatures();
    }

    // Media system initialization
    if (Platform.isWindows || Platform.isLinux) {
      JustAudioMediaKit.ensureInitialized();
      JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
      JustAudioMediaKit.title = 'ARE Music';
      JustAudioMediaKit.prefetchPlaylist = true;
    }

    // Configure system UI
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Create and initialize core services in correct order
    final panelKey = GlobalKey<NavigatorState>();
    final ytMusic = YTMusic();
    await ytMusic.init();

    // Create services that depend on SettingsManager
    final fileStorage = FileStorage();
    final mediaPlayer = MediaPlayer();
    final libraryService = LibraryService();

    // Register remaining singletons in dependency order
    GetIt.I
      ..registerSingleton<FileStorage>(fileStorage)
      ..registerSingleton<MediaPlayer>(mediaPlayer)
      ..registerSingleton<LibraryService>(libraryService)
      ..registerSingleton<DownloadManager>(DownloadManager())
      ..registerSingleton<YTMusic>(ytMusic)
      ..registerSingleton<Lyrics>(Lyrics())
      ..registerSingleton(panelKey);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => GetIt.I<SettingsManager>(),
          ),
          ChangeNotifierProvider(
            create: (_) => GetIt.I<MediaPlayer>(),
          ),
          ChangeNotifierProvider(
            create: (_) => GetIt.I<LibraryService>(),
          ),
          ChangeNotifierProvider(create: (_) {
            final provider = MusicLibraryProvider();
            provider.init();
            return provider;
          }),
        ],
        child: const ARE(),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
    // Show error UI instead of crashing
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child:
              Text('Error initializing app. Please restart the application.'),
        ),
      ),
    ));
  }
}

class ARE extends StatefulWidget {
  const ARE({super.key});

  @override
  State<ARE> createState() => _AREState();
}

class _AREState extends State<ARE> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadApp();
  }

  void _loadApp() {
    // Show splash for 5 seconds to ensure animation completes
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    SettingsManager settingsManager = context.watch<SettingsManager>();
    return DynamicColorBuilder(builder: (lightScheme, darkScheme) {
      return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: Platform.isWindows
            ? _buildFluentApp(
                settingsManager,
                lightScheme: lightScheme,
                darkScheme: darkScheme,
              )
            : MaterialApp.router(
                title: 'ARE Music',
                routerConfig: router,
                locale:
                    Locale(context.watch<SettingsManager>().language['value']!),
                localizationsDelegates: const [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: S.delegate.supportedLocales,
                debugShowCheckedModeBanner: false,
                themeMode: context.watch<SettingsManager>().themeMode,
                theme: lightTheme(
                  colorScheme: context.watch<SettingsManager>().dynamicColors &&
                          lightScheme != null
                      ? lightScheme
                      : ColorScheme.fromSeed(
                          seedColor:
                              context.watch<SettingsManager>().accentColor ??
                                  Colors.black,
                          primary:
                              context.watch<SettingsManager>().accentColor ??
                                  Colors.black,
                          brightness: Brightness.light,
                        ),
                ),
                darkTheme: darkTheme(
                  colorScheme: context.watch<SettingsManager>().dynamicColors &&
                          darkScheme != null
                      ? darkScheme
                      : ColorScheme.fromSeed(
                          seedColor:
                              context.watch<SettingsManager>().accentColor ??
                                  primaryWhite,
                          primary:
                              context.watch<SettingsManager>().accentColor ??
                                  primaryWhite,
                          brightness: Brightness.dark,
                          surface: context.watch<SettingsManager>().amoledBlack
                              ? Colors.black
                              : null,
                        ),
                ),
              ),
      );
    });
  }

  _buildFluentApp(SettingsManager settingsManager,
      {ColorScheme? lightScheme, ColorScheme? darkScheme}) {
    return fluent_ui.FluentApp.router(
      title: 'ARE Music',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: Locale(settingsManager.language['value']!),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      themeMode: settingsManager.themeMode,
      theme: fluent_ui.FluentThemeData(
        brightness: Brightness.light,
        accentColor: settingsManager.dynamicColors
            ? lightScheme?.primary.toAccentColor()
            : settingsManager.accentColor?.toAccentColor(),
        fontFamily: GoogleFonts.poppins().fontFamily,
        typography: fluent_ui.Typography.fromBrightness(
          brightness: Brightness.light,
        ),
        iconTheme: const fluent_ui.IconThemeData(color: Colors.black),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor:
            (settingsManager.windowEffect == WindowEffect.disabled &&
                    settingsManager.dynamicColors)
                ? lightScheme?.surface
                : null,
      ),
      darkTheme: fluent_ui.FluentThemeData(
        brightness: Brightness.dark,
        accentColor: settingsManager.dynamicColors
            ? darkScheme?.primary.toAccentColor()
            : settingsManager.accentColor?.toAccentColor(),
        fontFamily: GoogleFonts.poppins().fontFamily,
        typography: fluent_ui.Typography.fromBrightness(
          brightness: Brightness.dark,
        ),
        iconTheme: const fluent_ui.IconThemeData(color: Colors.white),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor:
            (settingsManager.windowEffect == WindowEffect.disabled)
                ? (settingsManager.dynamicColors
                    ? darkScheme?.surface
                    : settingsManager.amoledBlack
                        ? Colors.black
                        : null)
                : null,
      ),
      builder: (context, child) {
        return fluent_ui.NavigationPaneTheme(
          data: fluent_ui.NavigationPaneThemeData(
            backgroundColor:
                settingsManager.windowEffect == WindowEffect.disabled
                    ? null
                    : fluent_ui.Colors.transparent,
          ),
          child: child!,
        );
      },
    );
  }
}

initialiseHive() async {
  String? applicationDataDirectoryPath;
  if (Platform.isWindows || Platform.isLinux) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/database";
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox('SETTINGS');
  await Hive.openBox('LIBRARY');
  await Hive.openBox('SEARCH_HISTORY');
  await Hive.openBox('SONG_HISTORY');
  await Hive.openBox('FAVOURITES');
  await Hive.openBox('DOWNLOADS');
}

bool getInitialDarkness() {
  int themeMode = Hive.box('SETTINGS').get('THEME_MODE', defaultValue: 0);
  if (themeMode == 0) {
    return MediaQueryData.fromView(
                    WidgetsBinding.instance.platformDispatcher.views.first)
                .platformBrightness ==
            Brightness.dark
        ? true
        : false;
  } else if (themeMode == 2) {
    return true;
  }
  return false;
}

List<WindowEffect> get windowEffectList => [
      WindowEffect.disabled,
      WindowEffect.acrylic,
      WindowEffect.solid,
      WindowEffect.mica,
      WindowEffect.tabbed,
      WindowEffect.aero,
    ];
