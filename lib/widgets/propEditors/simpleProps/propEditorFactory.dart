

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'NumberPropTextField.dart';
import 'VectorPropEditor.dart';
import 'boolPropCheckbox.dart';
import 'propTextField.dart';

Widget makePropEditor<T extends PropTextField>(Prop prop, [PropTFOptions options = const PropTFOptions()]) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField<T>(prop: prop as HexProp, options: options);
    case PropType.number:
      return NumberPropTextField<T>(prop: prop as NumberProp, options: options);
    case PropType.vector:
      return VectorPropEditor<T>(prop: prop as VectorProp);
    case PropType.bool:
      return BoolPropCheckbox(prop: prop as BoolProp);
    default:
      return PropTextField.make<T>(prop: prop, options: options);
  }
}