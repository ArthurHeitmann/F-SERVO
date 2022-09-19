

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'NumberPropTextField.dart';
import 'propTextField.dart';

Widget makePropEditor(Prop prop) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField(prop: prop as HexProp);
    case PropType.number:
      return NumberPropTextField(prop: prop as NumberProp);
    default:
      return PropTextField(prop: prop);
  }
}