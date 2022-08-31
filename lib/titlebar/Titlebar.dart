import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nier_scripts_editor/titlebar/TitlebarButton.dart';
import 'package:window_manager/window_manager.dart';

final windowTitleProvider = StateProvider<String>((ref) => "Nier Scripts Editor");

class TitleBar extends ConsumerStatefulWidget {
  const TitleBar({Key? key}) : super(key: key);

  @override
  TitleBarState createState() => TitleBarState();
}

class TitleBarState extends ConsumerState<TitleBar> with WindowListener {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    init();
  }

  void init() async {
    isExpanded = await windowManager.isMaximized();
    var titleProvider = ref.read(windowTitleProvider.notifier);
    await windowManager.setTitle(titleProvider.state);
    titleProvider.state = await windowManager.getTitle();
  }

  @override
  void onWindowMaximize() {
    super.onWindowMaximize();
    setState(() {
      isExpanded = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    super.onWindowUnmaximize();
    setState(() {
      isExpanded = false;
    });
  }

  void toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    var title = ref.watch(windowTitleProvider);

    return Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(0x2d, 0x2d, 0x2d, 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 35,
          maxHeight: 35,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) => windowManager.startDragging(),
                onDoubleTap: toggleMaximize,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    // border: Border.all(color: Colors.cyanAccent),
                  ),
                  child: Text(title, textScaleFactor: 1.125)
                )
              ),
            ),
            TitleBarButton(
              icon: Icons.minimize,
              onPressed: windowManager.minimize,
              primaryColor: Colors.blue,
              
            ),
            TitleBarButton(
              icon: isExpanded ? Icons.expand_more : Icons.expand_less,
              onPressed: toggleMaximize,
              primaryColor: Colors.blue,
            ),
            TitleBarButton(
              icon: Icons.close,
              onPressed: windowManager.close,
              primaryColor: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }
}
