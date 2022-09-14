
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/Property.dart';
import '../../utils.dart';

class HexPropTextField extends ChangeNotifierWidget {
  final HexProp prop;

  HexPropTextField({super.key, required this.prop}) : super(notifier: prop);

  @override
  State<HexPropTextField> createState() => _HexPropTextFieldState();
}

class _HexPropTextFieldState extends ChangeNotifierState<HexPropTextField> {
  final _controller = TextEditingController();
  bool showHashString = false;
  String? errorMsg;
  
  String getDisplayText() => widget.prop.isHashed && showHashString ? widget.prop.strVal! : widget.prop.toString();
  
  @override
  void initState() {
    showHashString = widget.prop.isHashed;

    _controller.text = getDisplayText();

    super.initState();
  }

  @override
  void onNotified() {
    _controller.value = _controller.value.copyWith(text: getDisplayText());
    super.onNotified();
  }

  void onTextChange() {
    if (!showHashString && !isHexInt(_controller.text)) {
      setState(() => errorMsg = "Not a valid hex value");
      return;
    }
    setState(() => errorMsg = null);
    widget.prop.updateWith(_controller.text, isStr: showHashString);
  }

  void toggleHashString() {
    setState(() {
      showHashString = !showHashString;
      _controller.text = showHashString ? widget.prop.strVal ?? "?" : widget.prop.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.prop,
      builder: (context, value, child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(8.0),
          child: Row(
            children: [
              Opacity(
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
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => onTextChange(),
                  style: TextStyle(
                    fontSize: 13
                  ),
                  decoration: InputDecoration(
                    errorText: errorMsg,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}
