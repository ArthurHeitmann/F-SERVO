import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'customTheme.dart';
import 'keyboardEvents/globalShortcutsWrapper.dart';
import 'widgets/EditorLayout.dart';
import 'widgets/statusbar/statusbar.dart';
import 'widgets/titlebar/Titlebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
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

  runApp(MyApp());
}

final _rootKey = GlobalKey<ScaffoldState>();

BuildContext getGlobalContext() => _rootKey.currentContext!;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return globalShortcutsWrapper(context,
      child: MaterialApp(
        title: "Nier Scripts Editor",
        debugShowCheckedModeBanner: false,
        darkTheme: NierDarkThemeExtension.makeTheme(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          key: _rootKey,
          body: ContextMenuOverlay(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(),
                Expanded(child: EditorLayout()),
                Divider(height: 1),
                Statusbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
