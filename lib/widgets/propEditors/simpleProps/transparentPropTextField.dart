
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import 'propTextField.dart';

class TransparentPropTextField extends PropTextField {
  TransparentPropTextField({
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
  createState() => _TransparentPropTextFieldState();
}

class _TransparentPropTextFieldState extends PropTextFieldState {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: widget.prop,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: widget.constraints,
            child: Row(
              children: [
                if (widget.left != null)
                  widget.left!,
                if (widget.left == null)
                  const SizedBox(width: 8),
                Flexible(
                  child: TextField(
                    controller: controller,
                    onChanged: onTextChange,
                    style: getTheme(context).propInputTextStyle,
                    scrollController: ScrollController(keepScrollOffset: false),
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
        ),
      )
    );
  }
}
