
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../utils/utils.dart';
import '../../misc/ChangeNotifierWidget.dart';
import 'propTextField.dart';

class HexPropTextField<T extends PropTextField> extends ChangeNotifierWidget {
  final HexProp prop;
  final PropTFOptions options;

  HexPropTextField({super.key, required this.prop, this.options = const PropTFOptions()}) : super(notifier: prop);

  @override
  State<HexPropTextField> createState() => _HexPropTextFieldState<T>();
}

class _HexPropTextFieldState<T extends PropTextField> extends ChangeNotifierState<HexPropTextField> {
  final _controller = TextEditingController();
  bool showHashString = false;
  
  String getDisplayText() => widget.prop.isHashed && showHashString ? widget.prop.strVal! : widget.prop.toString();
  
  @override
  void initState() {
    showHashString = widget.prop.isHashed;
    super.initState();
  }

  void toggleHashString() {
    setState(() {
      showHashString = !showHashString;
      _controller.text = showHashString ? widget.prop.strVal ?? "?" : widget.prop.toString();
    });
  }

  String? textValidator(String str) {
    return !showHashString && !isHexInt(str)
      ? "Not a valid hex value"
      : null;
  }

  void onValidUpdateProp(String text) {
    widget.prop.updateWith(text, isStr: showHashString);
  }

  @override
  Widget build(BuildContext context) {
    return PropTextField.make<T>(
      prop: widget.prop,
      left: Opacity(
        opacity: showHashString ? 1.0 : 0.25,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 13,
          icon: const Icon(Icons.tag, size: 15,),
          onPressed: toggleHashString,
          isSelected: showHashString,
        ),
      ),
      options: widget.options,
      validatorOnChange: textValidator,
      onValid: onValidUpdateProp,
      controller: _controller,
      getDisplayText: getDisplayText,
    );
  }
}
