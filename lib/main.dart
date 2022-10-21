import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'background/IdLookup.dart';
import 'customTheme.dart';
import 'keyboardEvents/globalShortcutsWrapper.dart';
import 'stateManagement/preferencesData.dart';
import 'stateManagement/sync/syncServer.dart';
import 'widgets/EditorLayout.dart';
import 'widgets/misc/mousePosition.dart';
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

  startSyncServer();
  idLookup.init();
  PreferencesData().load();

  runApp(MyApp());
}

final _rootKey = GlobalKey<ScaffoldState>(debugLabel: "RootGlobalKey");

BuildContext getGlobalContext() => _rootKey.currentContext!;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return globalShortcutsWrapper(context,
      child: MousePosition(
        child: MaterialApp(
          title: "Nier Scripts Editor",
          debugShowCheckedModeBanner: false,
          darkTheme: NierDarkThemeExtension.makeTheme(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            key: _rootKey,
            body: ContextMenuOverlay(
              cardBuilder: (context, children) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 300, minWidth: 200),
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
                  Expanded(child: EditorLayout()),
                  Divider(height: 1),
                  Statusbar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
