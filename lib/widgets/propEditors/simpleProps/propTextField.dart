
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../utils.dart';

class PropTextField<P extends Prop> extends ChangeNotifierWidget {
  final P prop;
  final Widget? left;
  final BoxConstraints constraints;
  final String? Function(String str)? validatorOnChange;
  final void Function(String)? onValid;
  final TextEditingController? controller;
  final String Function()? getDisplayText;

  PropTextField({
    super.key,
    required this.prop,
    this.left,
    BoxConstraints? constraints,
    this.validatorOnChange,
    this.onValid,
    this.controller,
    this.getDisplayText,
  })
    : constraints = constraints ?? BoxConstraints(minWidth: 50),
    super(notifier: prop);

  @override
  State<PropTextField<P>> createState() => _PropTextFieldState<P>();
}

class _PropTextFieldState<P extends Prop> extends ChangeNotifierState<PropTextField<P>> {
  late final TextEditingController _controller;
  String? errorMsg;

  String _getDisplayText() => widget.prop.toString();
  String getDisplayText() => (widget.getDisplayText ?? _getDisplayText).call();

  @override
  void initState() {
    _controller = widget.controller ?? TextEditingController();
    _controller.text = getDisplayText();

    super.initState();
  }

  @override
  void onNotified() {
    var newText = getDisplayText();
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: clamp(_controller.selection.baseOffset, 0, newText.length)),
    );
    onTextChange(_controller.text);
    super.onNotified();
  }

  void onTextChange(String text) {
    if (widget.validatorOnChange != null) {
      var err = widget.validatorOnChange!(text);
      if (err != null) {
        setState(() => errorMsg = err);
        return;
      }
    }
    setState(() => errorMsg = null);
    widget.onValid?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: widget.prop,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(8.0),
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
                      controller: _controller,
                      onChanged: onTextChange,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: "FiraCode",
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
          ),
        ),
      )
    );
  }
}
