
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import 'SelectableListEntry.dart';
import 'SmoothScrollBuilder.dart';
import 'TextFieldFocusNode.dart';
import 'arrowNavigationList.dart';
import 'mousePosition.dart';

class SelectionPopupConfig<T> {
  final IconData? icon;
  final String name;
  final Key? key;
  final T Function() getValue;

  const SelectionPopupConfig({
    this.icon,
    required this.name,
    this.key,
    required this.getValue,
  });
}

Future<T?> showSelectionPopup<T>(BuildContext context, List<SelectionPopupConfig<T>> configs, { double? width }) {
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
        width: width,
        completer: completer,
      ),
    ),
  );

  return completer.future;
}

class _SelectionContextMenu extends StatefulWidget {
  final Offset pos;
  final List<SelectionPopupConfig> configs;
  final double? width;
  final Completer completer;

  const _SelectionContextMenu({required this.configs, required this.completer, required this.pos, this.width});

  @override
  State<_SelectionContextMenu> createState() => _SelectionContextMenuState();
}

class _SelectionContextMenuState extends State<_SelectionContextMenu> with ArrowNavigationList {
  static const popupWidthDefault = 400.0;
  double get popupWidth => widget.width ?? popupWidthDefault;
  static const maxPopupHeight = 210.0;
  static const entryHeight = 28.0;
  static const screenPadding = 10.0;
  final focusNode = TextFieldFocusNode();

  String search = "";
  
  @override
  get itemCount => widget.configs
    .where((config) => config.name.toLowerCase().contains(search.toLowerCase()))
    .length;

  @override
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
          constraints: BoxConstraints(minWidth: popupWidth, maxWidth: popupWidth, maxHeight: maxPopupHeight),
          child: SmoothSingleChildScrollView(
            child: Column(
              children: [
                makeSearchBar(),
                for (int i = 0; i < searchedConfigs.length; i++)
                  SelectableListEntry(
                    key: searchedConfigs[i].key ?? Key(searchedConfigs[i].name),
                    height: entryHeight,
                    icon: searchedConfigs[i].icon,
                    text: searchedConfigs[i].name,
                    isSelected: i == focusedIndex,
                    selectionChangeStream: selectionChangeStream.stream,
                    onPressed: () {
                      widget.completer.complete(searchedConfigs[i].getValue());
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget makeSearchBar() {
    return SizedBox(
      height: entryHeight,
      child: TextField(
        focusNode: focusNode,
        autofocus: true,
        onChanged: (value) {
          setState(() {
            search = value;
          });
        },
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: "Search...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget prepareLayout(BuildContext context, { required Widget child }) {
    var screenSize = MediaQuery.of(context).size;
    var expectedHeight = min(widget.configs.length * entryHeight, maxPopupHeight);
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
}
