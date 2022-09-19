
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../utils.dart';
import 'propTextField.dart';

class HexPropTextField extends ChangeNotifierWidget {
  final HexProp prop;
  final BoxConstraints? constraints;

  HexPropTextField({super.key, required this.prop, this.constraints}) : super(notifier: prop);

  @override
  State<HexPropTextField> createState() => _HexPropTextFieldState();
}

class _HexPropTextFieldState extends ChangeNotifierState<HexPropTextField> {
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
    return PropTextField(
      prop: widget.prop,
      left: Opacity(
        opacity: showHashString ? 1.0 : 0.25,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          splashRadius: 13,
          icon: Icon(Icons.tag, size: 15,),
          onPressed: toggleHashString,
          isSelected: showHashString,
        ),
      ),
      constraints: widget.constraints,
      validatorOnChange: textValidator,
      onValid: onValidUpdateProp,
      controller: _controller,
      getDisplayText: getDisplayText,
    );
  }
}
