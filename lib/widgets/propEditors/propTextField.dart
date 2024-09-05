
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../../utils/utils.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/TextFieldFocusNode.dart';
import '../misc/dropTargetBuilder.dart';
import '../theme/customTheme.dart';
import 'DoubleClickablePropTextField.dart';
import 'UnderlinePropTextField.dart';
import 'primaryPropTextField.dart';
import 'textFieldAutocomplete.dart';
import 'transparentPropTextField.dart';

class PropTFOptions {
  final Key? key;
  final BoxConstraints constraints;
  final bool isMultiline;
  final bool useIntrinsicWidth;
  final bool isFolderPath;
  final bool isFilePath;
  final String? hintText;
  final FutureOr<Iterable<AutocompleteConfig>> Function()? autocompleteOptions;

  const PropTFOptions({
    this.key,
    this.constraints = const BoxConstraints(minWidth: 50),
    this.isMultiline = false,
    this.useIntrinsicWidth = true,
    this.isFolderPath = false,
    this.isFilePath = false,
    this.hintText,
    this.autocompleteOptions,
  });

  PropTFOptions copyWith({
    Key? key,
    BoxConstraints? constraints,
    bool? isMultiline,
    bool? useIntrinsicWidth,
    bool? isFolderPath,
    bool? isFilePath,
    String? hintText,
    FutureOr<Iterable<AutocompleteConfig>> Function()? autocompleteOptions,
  }) {
    return PropTFOptions(
      key: key ?? this.key,
      constraints: constraints ?? this.constraints,
      isMultiline: isMultiline ?? this.isMultiline,
      useIntrinsicWidth: useIntrinsicWidth ?? this.useIntrinsicWidth,
      isFolderPath: isFolderPath ?? this.isFolderPath,
      isFilePath: isFilePath ?? this.isFilePath,
      hintText: hintText ?? this.hintText,
      autocompleteOptions: autocompleteOptions ?? this.autocompleteOptions,
    );
  }
}

abstract class PropTextField<P extends Prop> extends ChangeNotifierWidget {
  final P prop;
  final Widget? left;
  final PropTFOptions options;
  final String? Function(String str)? validatorOnChange;
  final void Function(String)? onValid;
  final TextEditingController? controller;
  final String Function()? getDisplayText;

  PropTextField({
    super.key,
    required this.prop,
    this.left,
    this.options = const PropTFOptions(),
    this.validatorOnChange,
    this.onValid,
    this.controller,
    this.getDisplayText,
  })
    : super(notifier: prop);

  static PropTextField make<T extends PropTextField>({
    Key? key,
    required Prop prop,
    Widget? left,
    PropTFOptions options = const PropTFOptions(),
    String? Function(String str)? validatorOnChange,
    void Function(String)? onValid,
    TextEditingController? controller,
    String Function()? getDisplayText,
  }) {
    if (T == DoubleClickablePropTextField)
      return DoubleClickablePropTextField(
        key: key ?? options.key,
        prop: prop,
        left: left,
        options: options,
        validatorOnChange: validatorOnChange,
        onValid: onValid,
        controller: controller,
        getDisplayText: getDisplayText,
      );
    if (T == UnderlinePropTextField)
      return UnderlinePropTextField(
        key: key ?? options.key,
        prop: prop,
        left: left,
        options: options,
        validatorOnChange: validatorOnChange,
        onValid: onValid,
        controller: controller,
        getDisplayText: getDisplayText,
      );
    if (T == TransparentPropTextField)
      return TransparentPropTextField(
        key: key ?? options.key,
        prop: prop,
        left: left,
        options: options,
        validatorOnChange: validatorOnChange,
        onValid: onValid,
        controller: controller,
        getDisplayText: getDisplayText,
      );
    // else if (T == PrimaryPropTextField)
    else {
      return PrimaryPropTextField(
        key: key ?? options.key,
        prop: prop,
        left: left,
        options: options,
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
  final FocusNode focusNode = TextFieldFocusNode();
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

  Widget applyWrappers({ required Widget child }) {
    return pathDropTargetWrapper(
      child: intrinsicWidthWrapper(
        child: child,
      ),
    );
  }
  
  Widget intrinsicWidthWrapper({ required Widget child }) => widget.options.useIntrinsicWidth
    ? IntrinsicWidth(child: child)
    : child;
  
  Widget pathDropTargetWrapper({ required Widget child }) => widget.options.isFolderPath || widget.options.isFilePath
    ? DropTargetBuilder(
        onDrop: (files) async {
          var file = files.first;
          if (!widget.options.isFolderPath && await Directory(file).exists()) {
            showToast("Expected a file, not a folder");
            return;
          }
          if (!widget.options.isFilePath && await File(file).exists()) {
            showToast("Expected a folder, not a file");
            return;
          }
            
          controller.text = file;
          onValid(file);
        },
        builder: (context, isDropping) => Stack(
          children: [
            child,
            if (isDropping)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: getTheme(context).editorBackgroundColor!.withOpacity(0.75),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      )
    : child;

}
