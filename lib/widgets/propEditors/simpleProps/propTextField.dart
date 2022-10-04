
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../utils.dart';
import 'DoubleClickablePropTextField.dart';
import 'primaryPropTextField.dart';

abstract class PropTextField<P extends Prop> extends ChangeNotifierWidget {
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

  static PropTextField make<T extends PropTextField>({
    Key? key,
    required Prop prop,
    Widget? left,
    BoxConstraints? constraints,
    String? Function(String str)? validatorOnChange,
    void Function(String)? onValid,
    TextEditingController? controller,
    String Function()? getDisplayText,
  }) {
    if (T == DoubleClickablePropTextField)
      return DoubleClickablePropTextField(
        key: key,
        prop: prop,
        left: left,
        constraints: constraints,
        validatorOnChange: validatorOnChange,
        onValid: onValid,
        controller: controller,
        getDisplayText: getDisplayText,
      );
    // else if (T == PrimaryPropTextField)
    else {
      return PrimaryPropTextField(
        key: key,
        prop: prop,
        left: left,
        constraints: constraints,
        validatorOnChange: validatorOnChange,
        onValid: onValid,
        controller: controller,
        getDisplayText: getDisplayText,
      );
    }
  }
}

abstract class PropTextFieldState<P extends Prop> extends ChangeNotifierState<PropTextField<P>> {
  late final TextEditingController controller;
  String? errorMsg;

  String _getDisplayText() => widget.prop.toString();
  String getDisplayText() => (widget.getDisplayText ?? _getDisplayText).call();

  void Function(String) get onValid => widget.onValid ?? widget.prop.updateWith;

  @override
  void initState() {
    controller = widget.controller ?? TextEditingController();
    controller.text = getDisplayText();

    super.initState();
  }

  @override
  void onNotified() {
    var newText = getDisplayText();
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: clamp(controller.selection.baseOffset, 0, newText.length)),
    );
    runValidator(controller.text);
    super.onNotified();
  }

  bool runValidator(String text) {
    if (widget.validatorOnChange != null) {
      var err = widget.validatorOnChange!(text);
      if (err != null) {
        if (errorMsg != err)
          setState(() => errorMsg = err);
        return false;
      }
    }
    if (errorMsg != null)
      setState(() => errorMsg = null);
    return true;
  }

  void onTextChange(String text) {
    if (!runValidator(text))
      return;
    onValid(text);
  }
}
