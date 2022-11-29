
import 'dart:async';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';

import 'background/IdLookup.dart';
import 'stateManagement/ChangeNotifierWidget.dart';
import 'utils/loggingWrapper.dart';
import 'utils/utils.dart';
import 'utils/assetDirFinder.dart';
import 'widgets/theme/customTheme.dart';
import 'keyboardEvents/globalShortcutsWrapper.dart';
import 'stateManagement/preferencesData.dart';
import 'stateManagement/sync/syncServer.dart';
import 'widgets/EditorLayout.dart';
import 'widgets/misc/mousePosition.dart';
import 'widgets/statusbar/statusbar.dart';
import 'widgets/titlebar/Titlebar.dart';

void main() {
  loggingWrapper(init);
}

void init() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(400, 200),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Color.fromRGBO(18, 18, 18, 1),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      var windowPos = await windowManager.getPosition();
      if (windowPos.dy < 50)
        await windowManager.setPosition(windowPos.translate(0, 50));
      // await windowManager.focus();
    });
  }
  else if (isMobile) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    await ensureHasStoragePermission();
  }

  startSyncServer();
  findAssetsDir();
  idLookup.init();
  await PreferencesData().load();

  runApp(const MyApp());
}

final _rootKey = GlobalKey<ScaffoldState>(debugLabel: "RootGlobalKey");

BuildContext getGlobalContext() => _rootKey.currentContext!;

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? hasPermission = isDesktop ? true : null;

  @override
  void initState() {
    super.initState();
    if (isMobile)
      ensureHasStoragePermission().then((value) => setState(() => hasPermission = value));
  }

  @override
  Widget build(BuildContext context) {
    if (hasPermission != true) {
      return MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: hasPermission == false ? const Center(
            child: Text("Please grant storage permission"),
          ) : const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ChangeNotifierBuilder(
      notifier: PreferencesData().themeType!,
      builder: (context) {
        return MaterialApp(
          title: "Nier Scripts Editor",
          debugShowCheckedModeBanner: false,
          theme: PreferencesData().makeTheme(),
          home: MyAppBody(key: _rootKey)
        );
      }
    );
  }
}

class MyAppBody extends StatelessWidget {
  const MyAppBody({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: Theme.of(context).brightness == Brightness.light ? _NierOverlayPainter() : null,
      child: globalShortcutsWrapper(context,
        child: MousePosition(
          child: ContextMenuOverlay(
            cardBuilder: (context, children) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, minWidth: 200),
              child: Material(
                color: getTheme(context).contextMenuBgColor,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                clipBehavior: Clip.antiAlias,
                elevation: 5,
                shadowColor: Colors.black,
                child: Column(
                  children: children,
                ),
              ),
            ),
            buttonBuilder: (context, config, [style]) => InkWell(
              onTap: config.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
                child: Row(
                  children: [
                    if (config.icon != null)
                      config.icon!,
                    if (config.icon != null)
                      const SizedBox(width: 8),
                    if (config.icon == null)
                      const SizedBox(width: 16),
                    Expanded(
                      child: Text(config.label, overflow: TextOverflow.ellipsis,)
                    ),
                    if (config.shortcutLabel != null)
                      Text(
                        config.shortcutLabel!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(),
                const Expanded(child: EditorLayout()),
                Divider(height: 1, color: getTheme(context).dividerColor),
                const Statusbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> ensureHasStoragePermission() async {
  if (!isMobile)
    return true;
  var storagePermission = await Permission.storage.status;
  var externalStoragePermission = await Permission.manageExternalStorage.status;
  if (!storagePermission.isGranted) {
    storagePermission = await Permission.storage.request();
    if (!storagePermission.isGranted)
      return false;
  }
  while (!externalStoragePermission.isGranted) {
    externalStoragePermission = await Permission.manageExternalStorage.request();
    if (!externalStoragePermission.isGranted)
      return false;
  }
  return true;
}

class _NierOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // grid
    const gridSize = 10;
    const gridColor = Color.fromARGB(10, 133, 125, 65);
    const lineW = 3.0;

    final paint = Paint()
      ..color = gridColor;

    for (double x = 0; x < size.width; x += gridSize)
      canvas.drawRect(Rect.fromLTWH(x, 0, lineW, size.height), paint);
    for (double y = 0; y < size.height; y += gridSize)
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineW), paint);
    
    // vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.0),
          Colors.black.withOpacity(0.2),
        ],
        stops: const [0.7, 5.0],
        center: Alignment.center,
        radius: 1.0,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
