
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/theme/customTheme.dart';
import 'mousePosition.dart';

class SelectionPopupConfig<T> {
  final IconData? icon;
  final String name;
  final T Function() getValue;

  const SelectionPopupConfig({
    this.icon,
    required this.name,
    required this.getValue,
  });
}

Future<T?> showSelectionPopup<T>(BuildContext context, List<SelectionPopupConfig<T>> configs) {
  var completer = Completer<T?>();
  
  var pos = MousePosition.pos;
  showDialog(context: context,
    barrierColor: Colors.transparent,
    builder: (context) => WillPopScope(
      onWillPop: () async {
        completer.complete(null);
        return true;
      },
      child: _SelectionContextMenu(
        pos: pos,
        configs: configs,
        completer: completer,
      ),
    ),
  );

  return completer.future;
}

class _SelectionContextMenu extends StatefulWidget {
  final Offset pos;
  final List<SelectionPopupConfig> configs;
  final Completer completer;

  const _SelectionContextMenu({required this.configs, required this.completer, required this.pos});

  @override
  State<_SelectionContextMenu> createState() => _SelectionContextMenuState();
}

class _SelectionContextMenuState extends State<_SelectionContextMenu> {
  static const popupWidth = 300.0;
  static const entryHeight = 28.0;
  static const screenPadding = 10.0;

  int focusedIndex = 0;
  String search = "";

  void moveFocus(int delta) {
    var searchedConfigsLength = widget.configs
      .where((config) => config.name.toLowerCase().contains(search.toLowerCase()))
      .length;
    focusedIndex = focusedIndex + delta;
    if (focusedIndex < -1)
      focusedIndex = searchedConfigsLength - 1;
    else if (focusedIndex >= searchedConfigsLength)
      focusedIndex = 0;
    setState(() { });
  }

  void selectFocused() {
    if (focusedIndex == -1) {
      widget.completer.complete(null);
    }
    else {
      var searchedConfigs = widget.configs
        .where((config) => config.name.toLowerCase().contains(search.toLowerCase()));
      var config = searchedConfigs.elementAt(focusedIndex);
      widget.completer.complete(config.getValue());
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    var searchedConfigs = widget.configs
      .where((config) => config.name.toLowerCase().contains(search.toLowerCase()))
      .toList();
    return prepareLayout(context,
      child: setupShortcuts(
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: popupWidth),
          child: Column(
            children: [
              makeSearchBar(),
              for (int i = 0; i < searchedConfigs.length; i++)
                  SizedBox(
                    height: entryHeight,
                    child: TextButton.icon(
                      icon: Icon(searchedConfigs[i].icon, size: 22,),
                      style: ButtonStyle(
                        foregroundColor: MaterialStateProperty.all(getTheme(context).textColor),
                        backgroundColor: MaterialStateProperty.all(focusedIndex == i ? Theme.of(context).highlightColor : Colors.transparent),
                        overlayColor: MaterialStateProperty.all(Theme.of(context).highlightColor.withOpacity(0.075)),
                      ),
                      label: SizedBox(
                        height: 25,
                        child: Row(
                          children: [
                            Expanded(child: Text(searchedConfigs[i].name)),
                          ],
                        ),
                      ),
                      onPressed: () {
                        widget.completer.complete(searchedConfigs[i].getValue());
                        Navigator.of(context).pop();
                      },
                    ),
                  )
            ],
          ),
        ),
      ),
    );
  }

  Widget makeSearchBar() {
    return SizedBox(
      height: entryHeight,
      child: TextField(
        autofocus: true,
        onChanged: (value) {
          setState(() {
            search = value;
          });
        },
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: "Search...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget prepareLayout(BuildContext context, { required Widget child }) {
    var screenSize = MediaQuery.of(context).size;
    var expectedHeight = widget.configs.length * entryHeight;
    var leftOffset = widget.pos.dx;
    var topOffset = widget.pos.dy;

    if (leftOffset + popupWidth + screenPadding > screenSize.width)
      leftOffset = max(0, screenSize.width - popupWidth - screenPadding);
    if (topOffset + expectedHeight + screenPadding > screenSize.height)
      topOffset = max(0, screenSize.height - expectedHeight - screenPadding);
    return Stack(
      children: [
        Positioned(
          left: leftOffset,
          top: topOffset,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(5),
            clipBehavior: Clip.antiAlias,
            color: getTheme(context).contextMenuBgColor,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget setupShortcuts({ required Widget child }) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): _FocusChangeIntent(-1, moveFocus),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): _FocusChangeIntent(1, moveFocus),
        LogicalKeySet(LogicalKeyboardKey.enter): _SubmitIntent(selectFocused),
      },
      child: Actions(
        actions: {
          _FocusChangeIntent: _FocusChangeAction(),
          _SubmitIntent: _SubmitAction(),
        },
        child: child,
      ),
    );
  }
}

class _FocusChangeIntent extends Intent {
  final int direction;
  final void Function(int delta) moveFocus;

  const _FocusChangeIntent(this.direction, this.moveFocus);
}

class _SubmitIntent extends Intent {
  final void Function() selectFocused;

  const _SubmitIntent(this.selectFocused);
}

class _FocusChangeAction extends Action<_FocusChangeIntent> {
  @override
  void invoke(_FocusChangeIntent intent) {
    intent.moveFocus(intent.direction);
  }
}

class _SubmitAction extends Action<_SubmitIntent> {
  @override
  void invoke(_SubmitIntent intent) {
    intent.selectFocused();
  }
}
