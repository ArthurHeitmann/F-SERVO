
import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class SelectableListEntry extends StatelessWidget {
  final double height;
  final IconData? icon;
  final bool reserveIconSpace;
  final String text;
  final bool isSelected;
  final VoidCallback? onPressed;
  final double scale;

  const SelectableListEntry({
    super.key,
    this.height = 28,
    this.icon,
    this.reserveIconSpace = true,
    required this.text,
    this.isSelected = false,
    this.onPressed,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      if (context.findRenderObject() == null)
        waitForNextFrame().then((_) {
          scrollIntoViewOptionally(context, duration: Duration.zero, smallStep: true);
        });
      else
        scrollIntoViewOptionally(context, duration: Duration.zero, smallStep: true);
    }
    return SizedBox(
      height: height,
      child: TextButton.icon(
        icon: Icon(icon, size: reserveIconSpace ? 22 * scale : 0,),
        style: ButtonStyle(
          padding: MaterialStateProperty.all(EdgeInsets.zero),
          foregroundColor: MaterialStateProperty.all(getTheme(context).textColor),
          backgroundColor: MaterialStateProperty.all(isSelected ? Theme.of(context).highlightColor : Colors.transparent),
          overlayColor: MaterialStateProperty.all(Theme.of(context).highlightColor.withOpacity(0.075)),
        ),
        label: SizedBox(
          height: height * 0.9,
          child: Row(
            children: [
              Expanded(child: Text(
                text,
                textScaleFactor: scale,
                overflow: TextOverflow.ellipsis,
              )),
            ],
          ),
        ),
        onPressed: onPressed,
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