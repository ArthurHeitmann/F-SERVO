
import 'dart:async';

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
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: widget.pos.dx,
          top: widget.pos.dy,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(5),
            clipBehavior: Clip.antiAlias,
            color: getTheme(context).contextMenuBgColor,
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: 300),
              child: Column(
                children: widget.configs.map((e) => TextButton.icon(
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
                )).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
