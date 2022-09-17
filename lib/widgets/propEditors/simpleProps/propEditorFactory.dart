

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'propTextField.dart';

Widget makePropEditor(Prop prop) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField(prop: prop as HexProp);
    default:
      return PropTextField(prop: prop);
  }
}