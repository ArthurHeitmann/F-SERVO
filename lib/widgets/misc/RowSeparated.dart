

import 'package:flutter/material.dart';

class RowSeparated extends StatelessWidget {
  final MainAxisSize? mainAxisSize;
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;

  final List<Widget> children;
  late final Widget Function(BuildContext context)? separator;
  final double? separatorWidth;

  RowSeparated({
    super.key,
    required this.children,
    Widget Function(BuildContext context)? separator,
    this.separatorWidth,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment
  }) {
    this.separator = separator ?? (context) => SizedBox(width: separatorWidth ?? 10);
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    for (var i = 0; i < this.children.length; i++) {
      children.add(this.children[i]);
      if (i < this.children.length - 1)
        children.add(separator!(context));
    }
    return Row(
      mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.start,
      mainAxisSize: mainAxisSize ?? MainAxisSize.max,
      children: children,
    );
  }
}
