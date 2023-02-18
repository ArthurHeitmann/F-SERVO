
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../stateManagement/Property.dart';
import '../../../utils/utils.dart';
import '../../misc/SelectableListEntry.dart';
import '../../misc/SmoothScrollBuilder.dart';
import '../../misc/arrowNavigationList.dart';
import '../../theme/customTheme.dart';

class AutocompleteConfig {
  final String searchText;
  final String displayText;
  final String insertText;
  final void Function()? onSelect;

  AutocompleteConfig(this.searchText, { String? displayText, String? insertText, this.onSelect})
    : displayText = displayText ?? searchText,
      insertText = insertText ?? searchText;
}

class TextFieldAutocomplete extends StatefulWidget {
  final FutureOr<Iterable<AutocompleteConfig>> Function()? getOptions;
  final FocusNode focusNode;
  final TextEditingController textController;
  final Prop prop;
  final Widget child;

  const TextFieldAutocomplete({
    super.key,
    this.getOptions,
    required this.focusNode,
    required this.textController,
    required this.prop,
    required this.child,
  });

  @override
  State<TextFieldAutocomplete> createState() => _TextFieldAutocompleteState();
}

class _TextFieldAutocompleteState extends State<TextFieldAutocomplete> {
  final layerLink = LayerLink();
  Iterable<AutocompleteConfig>? options;
  OverlayEntry? overlayEntry;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    if (widget.getOptions != null) (() async {
      options = await widget.getOptions!();
    })();
    super.initState();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    if (overlayEntry != null)
      _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus)
      _showOverlay();
    else
      _hideOverlay();
  }

  void _showOverlay() {
    if (options == null)
      return;
    if (overlayEntry != null)
      return;
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);
    overlayEntry = OverlayEntry(
      builder: (context) => _AutocompleteOverlay(
        layerLink: layerLink,
        options: options!,
        textController: widget.textController,
        focusNode: widget.focusNode,
        prop: widget.prop,
        offset: offset,
        size: size,
        child: widget.child,
      ),
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  void _hideOverlay() {
    if (overlayEntry == null)
      return;
    overlayEntry!.remove();
    overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          node.unfocus();
          return KeyEventResult.handled;
        }
        if ({ LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp }.contains(event.logicalKey) && overlayEntry != null) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: CompositedTransformTarget(
        link: layerLink,
        child: widget.child
      )
    );
  }
}

class _AutocompleteOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final Iterable<AutocompleteConfig> options;
  final TextEditingController textController;
  final FocusNode focusNode;
  final Prop prop;
  final Offset offset;
  final Size size;
  final Widget child;

  const _AutocompleteOverlay({
    required this.layerLink,
    required this.options,
    required this.textController,
    required this.focusNode,
    required this.prop,
    required this.offset,
    required this.size,
    required this.child,
  });

  @override
  State<_AutocompleteOverlay> createState() => __AutocompleteOverlayState();
}

class __AutocompleteOverlayState extends State<_AutocompleteOverlay> with ArrowNavigationList {
  late Iterable<AutocompleteConfig> filteredOptions;
  String? prevText;
  final scrollController = ScrollController();

  @override
  void initState() {
    filteredOptions = widget.options;
    widget.textController.addListener(_onTextChange);
    _onTextChange();
    super.initState();
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    var searchText = widget.textController.text.toLowerCase();
    int cursorCharIndex = widget.textController.selection.baseOffset;
    if (cursorCharIndex == -1)
      cursorCharIndex = searchText.length;
    else if (cursorCharIndex > searchText.length)
      cursorCharIndex = searchText.length;
    searchText = searchText.substring(0, cursorCharIndex);
    if (searchText == prevText)
      return;
    prevText = searchText;
    filteredOptions = widget.options
      .where((option) => option.searchText.toLowerCase().contains(searchText));
    if (scrollController.hasClients)
      scrollController.jumpTo(0);
    focusedIndex = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CompositedTransformFollower(
          link: widget.layerLink,
          offset: Offset(0, widget.size.height),
          child: setupShortcuts(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 200,
                maxWidth: 300,
                maxHeight: 215,
              ),
              child: SmoothSingleChildScrollView(
                controller: scrollController,
                child: Material(
                  color: getTheme(context).contextMenuBgColor,
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      filteredOptions.length,
                      (index) {
                        var option = filteredOptions.elementAt(index);
                        return SelectableListEntry(
                          height: 25,
                          text: option.displayText,
                          isSelected: index == focusedIndex,
                          scale: 0.85,
                          reserveIconSpace: false,
                          onPressed: () => onOptionSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  int get itemCount => filteredOptions.length;
  
  @override
  void selectFocused() {
    if (itemCount == 0)
      return;
    if (focusedIndex < 0 || focusedIndex >= itemCount)
      return;
    var option = filteredOptions.elementAt(focusedIndex);
    onOptionSelected(option);
  }

  void onOptionSelected(AutocompleteConfig option) {
    widget.textController.text = option.displayText;
    if (widget.prop is! HexProp || isHexInt(option.displayText))
      widget.prop.updateWith(option.insertText);
    else
      (widget.prop as HexProp).updateWith(option.insertText, isStr: true);
    option.onSelect?.call();
    widget.focusNode.unfocus();
  }
}
