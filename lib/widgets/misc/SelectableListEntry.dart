
import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class SelectableListEntry extends StatefulWidget {
  final double height;
  final IconData? icon;
  final bool reserveIconSpace;
  final String text;
  final bool isSelected;
  final VoidCallback? onPressed;
  final double scale;
  final Stream<void> selectionChangeStream;

  const SelectableListEntry({
    super.key,
    this.height = 28,
    this.icon,
    this.reserveIconSpace = true,
    required this.text,
    this.isSelected = false,
    required this.selectionChangeStream,
    this.onPressed,
    this.scale = 1.0,
  });

  @override
  State<SelectableListEntry> createState() => _SelectableListEntryState();
}

class _SelectableListEntryState extends State<SelectableListEntry> {
  late StreamSubscription<void> selectionChangeStreamSubscription;
  bool hasPendingChange = false;

  @override
  void initState() {
    selectionChangeStreamSubscription = widget.selectionChangeStream.listen((_) {
      hasPendingChange = true;
    });
    super.initState();
  }

  @override
  void dispose() {
    selectionChangeStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSelected && hasPendingChange) {
      if (context.findRenderObject() == null)
        waitForNextFrame().then((_) {
          scrollIntoViewOptionally(context, duration: Duration.zero, smallStep: true);
        });
      else
        scrollIntoViewOptionally(context, duration: Duration.zero, smallStep: true);
    }
    hasPendingChange = false;
    return SizedBox(
      height: widget.height,
      child: TextButton.icon(
        icon: Icon(widget.icon, size: widget.reserveIconSpace ? 22 * widget.scale : 0,),
        style: ButtonStyle(
          padding: MaterialStateProperty.all(EdgeInsets.zero),
          foregroundColor: MaterialStateProperty.all(getTheme(context).textColor),
          backgroundColor: MaterialStateProperty.all(widget.isSelected ? Theme.of(context).highlightColor : Colors.transparent),
          overlayColor: MaterialStateProperty.all(Theme.of(context).highlightColor.withOpacity(0.075)),
        ),
        label: SizedBox(
          height: widget.height * 0.9,
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: widget.text.length > 44 ? widget.text : "",
                  child: Text(
                    widget.text,
                    textScaleFactor: widget.scale,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class ListEntryFocusChangeIntent extends Intent {
  final int direction;
  final void Function(int delta) moveFocus;

  const ListEntryFocusChangeIntent(this.direction, this.moveFocus);
}

class ListEntrySubmitIntent extends Intent {
  final void Function() selectFocused;

  const ListEntrySubmitIntent(this.selectFocused);
}

class ListEntryFocusChangeAction extends Action<ListEntryFocusChangeIntent> {
  @override
  void invoke(ListEntryFocusChangeIntent intent) {
    intent.moveFocus(intent.direction);
  }
}

class ListEntrySubmitAction extends Action<ListEntrySubmitIntent> {
  @override
  void invoke(ListEntrySubmitIntent intent) {
    intent.selectFocused();
  }
}