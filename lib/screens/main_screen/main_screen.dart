import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/music_library_provider.dart';
import '../../services/file_scanner.dart';
import '../../generated/l10n.dart';
import '../../themes/text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/bottom_modals.dart';
import '../../utils/check_update.dart';
import '../browse_screen/browse_screen.dart';
import 'bottom_player.dart';

class LibraryIconPainter extends CustomPainter {
  final Color color;

  LibraryIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.8),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 0.8),
      paint,
    );

    final path = Path();
    path.moveTo(size.width * 0.65, size.height * 0.2);
    path.lineTo(size.width * 0.85, size.height * 0.25);
    path.lineTo(size.width * 0.85, size.height * 0.75);
    path.lineTo(size.width * 0.65, size.height * 0.8);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HomeIconPainter extends CustomPainter {
  final Color color;

  HomeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.2, size.height * 0.45);
    path.lineTo(size.width * 0.3, size.height * 0.45);
    path.lineTo(size.width * 0.3, size.height * 0.8);
    path.lineTo(size.width * 0.7, size.height * 0.8);
    path.lineTo(size.width * 0.7, size.height * 0.45);
    path.lineTo(size.width * 0.8, size.height * 0.45);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SettingsIconPainter extends CustomPainter {
  final Color color;

  SettingsIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.3),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.3),
      size.width * 0.08,
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.8, size.height * 0.5),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.5),
      size.width * 0.08,
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.8, size.height * 0.7),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.7),
      size.width * 0.08,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('MainScreen'));
  final StatefulNavigationShell navigationShell;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  late StreamSubscription _intentSub;

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    if (Platform.isAndroid) {
      _intentSub =
          ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        if (value.isNotEmpty) _handleIntent(value.first);
      });

      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) _handleIntent(value.first);
        ReceiveSharingIntent.instance.reset();
      });
    }

    _update();
  }

  bool _hasScanned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndScanOnce();
  }

  Future<void> _checkAndScanOnce() async {
    if (_hasScanned) return;
    _hasScanned = true;
    final prefs = await SharedPreferences.getInstance();
    final scanned = prefs.getBool('all_music_scanned') ?? false;
    if (!scanned) {
      await _scanAllMusicAtStart();
      await prefs.setBool('all_music_scanned', true);
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Android SDK version: ${androidInfo.version.sdkInt}');
      bool granted = false;
      if (androidInfo.version.sdkInt >= 33) {
        print('Requesting Permission.audio');
        granted = await Permission.audio.request().isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        print('Requesting Permission.storage');
        granted = await Permission.storage.request().isGranted;
        if (!granted) {
          print('Requesting Permission.manageExternalStorage');
          granted = await Permission.manageExternalStorage.request().isGranted;
        }
      } else {
        print('Requesting Permission.storage (Android 10 and below)');
        granted = await Permission.storage.request().isGranted;
      }
      print('Permission granted: $granted');
      return granted;
    }
    print('Requesting Permission.storage (non-Android)');
    bool granted = await Permission.storage.request().isGranted;
    print('Permission granted: $granted');
    return granted;
  }

  Future<void> _scanAllMusicAtStart() async {
    if (!mounted) return;
    try {
      bool hasPermission = await requestPermissions();
      print('Has permission: $hasPermission');
      if (hasPermission) {
        final provider =
            Provider.of<MusicLibraryProvider>(context, listen: false);
        await provider.scanAllMusicFiles(FileScanner.scanAllMusicFiles);
        if (provider.allMusicFiles.isEmpty && mounted) {
          print('No music files found.');
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(
                  "No music files found. Please check storage permissions.")));
        } else if (mounted) {
          print('Found ${provider.allMusicFiles.length} music files');
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content:
                  Text("Found ${provider.allMusicFiles.length} music files")));
        }
      } else {
        print('Permission not granted.');
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(
                  "Permission not granted. Please enable storage permissions in Settings.")));
        }
      }
    } catch (e) {
      print("Error in permission/scanning: $e");
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text("Error scanning files: $e")));
      }
    }
  }

  _handleIntent(SharedMediaFile value) {
    if (value.mimeType == 'text/plain' &&
        value.path.contains('music.youtube.com')) {
      Uri? uri = Uri.tryParse(value.path);
      if (uri != null) {
        if (uri.pathSegments.first == 'watch' &&
            uri.queryParameters['v'] != null) {
          context.push('/player', extra: uri.queryParameters['v']);
        } else if (uri.pathSegments.first == 'playlist' &&
            uri.queryParameters['list'] != null) {
          String id = uri.queryParameters['list']!;
          Navigator.push(
            context,
            AdaptivePageRoute.create(
              (_) => BrowseScreen(
                  endpoint: {'browseId': id.startsWith('VL') ? id : 'VL$id'}),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _intentSub.cancel();
    super.dispose();
  }

  _update() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    BaseDeviceInfo deviceInfo = await deviceInfoPlugin.deviceInfo;
    UpdateInfo? updateInfo = await Isolate.run(() async {
      return await checkUpdate(deviceInfo: deviceInfo);
    });

    if (updateInfo != null && mounted) {
      Modals.showUpdateDialog(context, updateInfo);
    }
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void onWindowClose() async {
    windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    bool isLandscape = screenWidth > screenHeight;

    return Platform.isWindows
        ? _buildWindowsMain(_goBranch, widget.navigationShell)
        : Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                // Base content layer
                Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (screenWidth >= 450)
                            NavigationRail(
                              backgroundColor: Colors.transparent,
                              labelType: NavigationRailLabelType.none,
                              selectedLabelTextStyle:
                                  smallTextStyle(context, bold: true),
                              extended: (screenWidth > 1000),
                              onDestinationSelected: _goBranch,
                              destinations:
                                  _buildNavigationDestinations(context),
                              selectedIndex:
                                  widget.navigationShell.currentIndex,
                            ),
                          Expanded(child: widget.navigationShell),
                        ],
                      ),
                    ),
                  ],
                ),

                // Floating controls layer - will stay below bottom sheets
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Spacer(),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width:
                            isLandscape ? screenWidth * 0.95 : double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 1 : screenWidth * 0.02,
                            vertical: screenWidth < 450 ? 3 : 12),
                        child: const BottomPlayer(),
                      ),
                    ),
                    if (screenWidth < 450)
                      Padding(
                        padding: EdgeInsets.only(
                          left: isLandscape ? 12 : screenWidth * 0.03,
                          right: isLandscape ? 12 : screenWidth * 0.03,
                          bottom: 8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              height: isLandscape ? 50 : 60,
                              width: isLandscape
                                  ? screenWidth * 0.4
                                  : double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.15),
                                  width: 1.0,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.03),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: BottomNavigationBar(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                currentIndex:
                                    widget.navigationShell.currentIndex,
                                onTap: _goBranch,
                                selectedFontSize: isLandscape ? 7 : 8,
                                unselectedFontSize: isLandscape ? 7 : 8,
                                iconSize: isLandscape ? 22 : 26,
                                showSelectedLabels: true,
                                showUnselectedLabels: true,
                                selectedItemColor:
                                    Theme.of(context).colorScheme.primary,
                                unselectedItemColor: Colors.white60,
                                type: BottomNavigationBarType.fixed,
                                items: _buildNavigationBarItems(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
  }

  List<NavigationRailDestination> _buildNavigationDestinations(
      BuildContext context) {
    return [
      NavigationRailDestination(
        selectedIcon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: HomeIconPainter(Theme.of(context).colorScheme.primary),
          ),
        ),
        icon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: HomeIconPainter(Colors.white70),
          ),
        ),
        label: Text(
          S.of(context).Home,
          style: smallTextStyle(context, bold: false),
        ),
      ),
      NavigationRailDestination(
        selectedIcon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: LibraryIconPainter(Theme.of(context).colorScheme.primary),
          ),
        ),
        icon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: LibraryIconPainter(Colors.white70),
          ),
        ),
        label: Text(
          S.of(context).Saved,
          style: smallTextStyle(context, bold: false),
        ),
      ),
      NavigationRailDestination(
        selectedIcon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: SettingsIconPainter(Theme.of(context).colorScheme.primary),
          ),
        ),
        icon: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: SettingsIconPainter(Colors.white70),
          ),
        ),
        label: Text(
          S.of(context).Settings,
          style: smallTextStyle(context, bold: false),
        ),
      )
    ];
  }

  List<BottomNavigationBarItem> _buildNavigationBarItems(BuildContext context) {
    return [
      BottomNavigationBarItem(
        icon: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: HomeIconPainter(widget.navigationShell.currentIndex == 0
                ? Theme.of(context).colorScheme.primary
                : Colors.white60),
          ),
        ),
        label: S.of(context).Home,
      ),
      BottomNavigationBarItem(
        icon: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: LibraryIconPainter(widget.navigationShell.currentIndex == 1
                ? Theme.of(context).colorScheme.primary
                : Colors.white60),
          ),
        ),
        label: S.of(context).Saved,
      ),
      BottomNavigationBarItem(
        icon: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: SettingsIconPainter(
                widget.navigationShell.currentIndex == 2
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white60),
          ),
        ),
        label: S.of(context).Settings,
      ),
    ];
  }

  Widget _buildWindowsMain(
      Function goTOBranch, StatefulNavigationShell navigationShell) {
    return Directionality(
      textDirection: fluent_ui.TextDirection.ltr,
      child: fluent_ui.NavigationView(
        appBar: fluent_ui.NavigationAppBar(
          title: DragToMoveArea(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(S.of(context).Gyawun),
            ),
          ),
          leading: fluent_ui.Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 96,
              height: 56,
              child: Image.asset(
                'assets/images/are.png',
                width: 96,
                height: 56,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          actions: const WindowButtons(),
        ),
        paneBodyBuilder: (item, body) {
          return Column(
            children: [
              fluent_ui.Expanded(child: navigationShell),
              const BottomPlayer()
            ],
          );
        },
        pane: fluent_ui.NavigationPane(
          selected: widget.navigationShell.currentIndex,
          size: const fluent_ui.NavigationPaneSize(
            compactWidth: 60,
          ),
          items: [
            fluent_ui.PaneItem(
              key: const ValueKey('/'),
              icon: SizedBox(
                width: 30,
                height: 30,
                child: CustomPaint(
                  painter: HomeIconPainter(Colors.white),
                ),
              ),
              title: Text(S.of(context).Home),
              body: const SizedBox.shrink(),
              onTap: () => goTOBranch(0),
            ),
            fluent_ui.PaneItem(
              key: const ValueKey('/saved'),
              icon: SizedBox(
                width: 30,
                height: 30,
                child: CustomPaint(
                  painter: LibraryIconPainter(Colors.white),
                ),
              ),
              title: Text(S.of(context).Saved),
              body: const SizedBox.shrink(),
              onTap: () => goTOBranch(1),
            ),
          ],
          footerItems: [
            fluent_ui.PaneItem(
              key: const ValueKey('/settings'),
              icon: SizedBox(
                width: 30,
                height: 30,
                child: CustomPaint(
                  painter: SettingsIconPainter(Colors.white),
                ),
              ),
              title: Text(S.of(context).Settings),
              body: const SizedBox.shrink(),
              onTap: () => goTOBranch(2),
            )
          ],
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final fluent_ui.FluentThemeData theme = fluent_ui.FluentTheme.of(context);

    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
