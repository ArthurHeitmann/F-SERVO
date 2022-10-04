

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'NumberPropTextField.dart';
import 'VectorPropEditor.dart';
import 'propTextField.dart';

Widget makePropEditor<T extends PropTextField>(Prop prop, [BoxConstraints? constraints]) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField<T>(prop: prop as HexProp, constraints: constraints);
    case PropType.number:
      return NumberPropTextField<T>(prop: prop as NumberProp, constraints: constraints);
    case PropType.vector:
      return VectorPropEditor<T>(prop: prop as VectorProp);
    default:
      return PropTextField.make<T>(prop: prop, constraints: constraints);
  }
}