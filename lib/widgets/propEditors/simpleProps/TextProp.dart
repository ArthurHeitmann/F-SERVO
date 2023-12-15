

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../misc/ChangeNotifierWidget.dart';

class TextProp extends ChangeNotifierWidget {
  final Prop prop;
  final TextStyle? style;
  final TextOverflow? overflow;

  TextProp({super.key, required this.prop, this.style, this.overflow}) : super(notifier: prop);

  @override
  State<TextProp> createState() => _TextPropState();
}

class _TextPropState extends ChangeNotifierState<TextProp> {
  @override
  Widget build(BuildContext context) {
    return Text(
      widget.prop.toString(),
      style: widget.style,
      overflow: widget.overflow,
    );
  }
}
