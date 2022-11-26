
import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import 'propTextField.dart';
import 'textFieldAutocomplete.dart';

class DoubleClickablePropTextField extends PropTextField {
  DoubleClickablePropTextField({
    super.key,
    required super.prop,
    super.left,
    super.options,
    super.validatorOnChange,
    super.onValid,
    super.controller,
    super.getDisplayText,
  }) : super();

  @override
  createState() => _DoubleClickablePropTextFieldState();
}

class _DoubleClickablePropTextFieldState extends PropTextFieldState {
  bool showInput = false;

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
      builder: (context) => intrinsicWidthWrapper(
        child: ConstrainedBox(
          constraints: widget.options.constraints,
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
                  child: TextFieldAutocomplete(
                    focusNode: focusNode,
                    textController: controller,
                    prop: widget.prop,
                    getOptions: widget.options.autocompleteOptions,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onTextChange,
                      style: getTheme(context).propInputTextStyle,
                      scrollController: ScrollController(keepScrollOffset: false),
                      maxLines: widget.options.isMultiline ? null : 1,
                      keyboardType: widget.options.isMultiline ? TextInputType.multiline : null,
                      decoration: InputDecoration(
                        hintText: widget.options.hintText,
                      ),
                    ),
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
