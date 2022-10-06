
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import 'propTextField.dart';

class DoubleClickablePropTextField extends PropTextField {
  DoubleClickablePropTextField({
    super.key,
    required super.prop,
    super.left,
    BoxConstraints? constraints,
    super.validatorOnChange,
    super.onValid,
    super.controller,
    super.getDisplayText,
  }) : super(constraints: constraints);

  @override
  createState() => _DoubleClickablePropTextFieldState();
}

class _DoubleClickablePropTextFieldState extends PropTextFieldState {
  bool showInput = false;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    focusNode.addListener(onFocusChange);
    super.initState();
  }

  @override
  void dispose() {
    focusNode.removeListener(onFocusChange);
    super.dispose();
  }

  void onFocusChange() {
    if (!focusNode.hasFocus && showInput) {
      setState(() => showInput = false);
    }
    else if (focusNode.hasFocus && !showInput) {
      setState(() => showInput = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: widget.prop,
      builder: (context) => IntrinsicWidth(
        child: ConstrainedBox(
          constraints: widget.constraints,
          child: Row(
            children: [
              if (widget.left != null)
                widget.left!,
              if (widget.left == null)
                const SizedBox(width: 8),
              Flexible(
                child: showInput ? Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onTextChange,
                    style: getTheme(context).propInputTextStyle,
                    focusNode: focusNode,
                  ),
                )
                : Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6, right: 2),
                  child: GestureDetector(
                    onDoubleTap: () {
                      setState(() => showInput = !showInput);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        focusNode.requestFocus();
                      });
                    },
                    child: Text(
                      getDisplayText(),
                      style: getTheme(context).propInputTextStyle,
                    ),
                  ),
                ),
              ),
              if (errorMsg != null)
                Tooltip(
                  message: errorMsg!,
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Icon(
                    Icons.error,
                    color: Colors.red.shade700,
                    size: 15,
                  ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      )
    );
  }
}
