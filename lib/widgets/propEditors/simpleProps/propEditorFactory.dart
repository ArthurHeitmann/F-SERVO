

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'NumberPropTextField.dart';
import 'VectorPropEditor.dart';
import 'primaryPropTextField.dart';

Widget makePropEditor(Prop prop, [BoxConstraints? constraints]) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField(prop: prop as HexProp, constraints: constraints);
    case PropType.number:
      return NumberPropTextField(prop: prop as NumberProp, constraints: constraints);
    case PropType.vector:
      return VectorPropEditor(prop: prop as VectorProp);
    default:
      return PrimaryPropTextField(prop: prop, constraints: constraints);
  }
}