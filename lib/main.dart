import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nier_scripts_editor/EditorLayout.dart';
import 'package:nier_scripts_editor/customTheme.dart';
import 'package:nier_scripts_editor/titlebar/Titlebar.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(400, 200),
    titleBarStyle: TitleBarStyle.hidden
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    var windowPos = await windowManager.getPosition();
    if (windowPos.dy < 50)
      await windowManager.setPosition(windowPos.translate(0, 50));
    // await windowManager.focus();
  });

  runApp(ProviderScope(
    child: MyApp()
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Nier Scripts Editor",
      debugShowCheckedModeBanner: false,
      darkTheme: NierDarkThemeExtension.makeTheme(),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: ContextMenuOverlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(),
              Expanded(child: EditorLayout()),
            ],
          ),
        ),
      ),
    );
  }
}

