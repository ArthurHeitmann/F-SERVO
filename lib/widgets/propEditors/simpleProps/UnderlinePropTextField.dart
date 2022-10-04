
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import 'propTextField.dart';

class UnderlinePropTextField extends PropTextField {
  UnderlinePropTextField({
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
  State createState() => _UnderlinePropTextFieldState();
}

class _UnderlinePropTextFieldState extends PropTextFieldState {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: widget.prop,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
          ),
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
        ),
      )
    );
  }
}
