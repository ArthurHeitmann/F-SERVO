
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';

import 'background/IdLookup.dart';
import 'background/wemFilesIndexer.dart';
import 'keyboardEvents/globalShortcutsWrapper.dart';
import 'stateManagement/beforeExitCleanup.dart';
import 'stateManagement/hierarchy/FileHierarchy.dart';
import 'stateManagement/openFiles/openFilesManager.dart';
import 'stateManagement/openFiles/types/xml/sync/syncServer.dart';
import 'stateManagement/preferencesData.dart';
import 'utils/assetDirFinder.dart';
import 'utils/fileOpenCommand.dart';
import 'utils/loggingWrapper.dart';
import 'utils/utils.dart';
import 'version/updateRestartData.dart';
import 'widgets/EditorLayout.dart';
import 'widgets/misc/ChangeNotifierWidget.dart';
import 'widgets/misc/mousePosition.dart';
import 'widgets/splashScreen/splashScreen.dart';
import 'widgets/statusbar/statusbar.dart';
import 'widgets/theme/customTheme.dart';
import 'widgets/theme/nierTheme.dart';
import 'widgets/titlebar/Titlebar.dart';

void main(List<String> args) {
  loggingWrapper(() => init(args));
}

void init(List<String> args) async {
  if (args.isNotEmpty) {
    var paths = args.where((arg) => FileSystemEntity.typeSync(arg) != FileSystemEntityType.notFound).toList();
    if (await trySendFileArgs(paths)) {
      exit(0);
    }
  }

  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SplashScreen());
  await Future.delayed(const Duration(milliseconds: 50));

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(400, 200),
      titleBarStyle: TitleBarStyle.hidden,
    );
    unawaited(windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      var windowPos = await windowManager.getPosition();
      if (windowPos.dy < 50)
        await windowManager.setPosition(windowPos.translate(0, 50));
      // await windowManager.focus();
    }));
  }
  else if (isMobile) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    await ensureHasStoragePermission();
  }

  startSyncServer();
  unawaited(findAssetsDir());
  unawaited(idLookup.init());
  await PreferencesData().load();
  unawaited(wemFilesLookup.updateIndex());
  unawaited(FlutterWindowClose.setWindowShouldCloseHandler(beforeExitConfirmation));

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          double padding = 16;
          if (constraints.maxWidth < 400 || constraints.maxHeight < 200)
            padding = 0;
          else if (constraints.maxWidth < 600 || constraints.maxHeight < 300)
            padding = 4;
          return Container(
            padding: EdgeInsets.all(padding),
            color: Colors.red.shade800,
            child: const Column(
              children: [
                Text(":(", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Something went wrong"),
              ],
            ),
          );
        }
      ),
    );
  };

  runApp(const MyApp());

  unawaited(waitForNextFrame().then((_) async {
    if (args.length >= 2) {
      if (args[0] == "--update-data") {
        var b64Json = args[1];
        var updateDataJson = jsonDecode(utf8.decode(base64Decode(b64Json)));
        var updateData = UpdateRestartData.fromJson(updateDataJson);
        for (var file in updateData.openedHierarchyFiles) {
          await openHierarchyManager.openFile(file);
        }
        for (var file in updateData.openedFiles) {
          areasManager.openFile(file);
        }
      }
    }
    for (var arg in args) {
      if (!await File(arg).exists() && !await Directory(arg).exists())
        continue;
      await openHierarchyManager.openFile(arg);
      if (await canOpenAsFile(arg))
        areasManager.openFile(arg);
    }
  }));
}

final _rootKey = GlobalKey<ScaffoldState>(debugLabel: "RootGlobalKey");

final routeObserver = RouteObserver<Route>();

BuildContext getGlobalContext() => _rootKey.currentContext!;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
          title: "F-SERVO",
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          theme: PreferencesData().makeTheme(context),
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
      foregroundPainter: Theme.of(context).brightness == Brightness.light ? const NierOverlayPainter() : null,
      child: globalShortcutsWrapper(context,
        child: MousePosition(
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
