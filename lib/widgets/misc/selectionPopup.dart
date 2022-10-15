
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../customTheme.dart';
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

  @override
  Widget build(BuildContext context) {
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
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: popupWidth),
              child: Column(
                children: widget.configs.map((e) => SizedBox(
                  height: entryHeight,
                  child: TextButton.icon(
                    autofocus: widget.configs.indexOf(e) == 0,
                    icon: Icon(e.icon, size: 22,),
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all(getTheme(context).textColor),
                    ),
                    label: SizedBox(
                      height: 25,
                      child: Row(
                        children: [
                          Expanded(child: Text(e.name)),
                        ],
                      ),
                    ),
                    onPressed: () {
                      widget.completer.complete(e.getValue());
                      Navigator.of(context).pop();
                    },
                  ),
                )).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
