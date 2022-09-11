
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/Property.dart';
import '../../utils.dart';

class HexPropTextField extends StatefulWidget {
  final HexProp prop;

  const HexPropTextField({super.key, required this.prop});

  @override
  State<HexPropTextField> createState() => _HexPropTextFieldState();
}

class _HexPropTextFieldState extends State<HexPropTextField> {
  final _controller = TextEditingController();
  bool showHashString = false;

  @override
  void initState() {
    showHashString = widget.prop.isHashed;

    _controller.text = widget.prop.isHashed ? widget.prop.strVal! : widget.prop.toString();

    super.initState();
  }

  void onTextChange(String str) {
    if (!isHexInt(str))
      return;
    widget.prop.updateWith(str, isStr: showHashString);
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
          color: getTheme(context).textFieldBgColor,
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
                child: TextFormField(
                  controller: _controller,
                  onChanged: onTextChange,
                  style: TextStyle(
                    fontSize: 13
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
