

import 'package:flutter/material.dart';

class ColumnSeparated extends StatelessWidget {
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;

  final List<Widget> children;
  late final Widget Function(BuildContext context)? separator;
  final double? separatorHeight;

  ColumnSeparated({super.key, required this.children, Widget Function(BuildContext context)? separator, this.separatorHeight, this.mainAxisAlignment, this.crossAxisAlignment}) {
    this.separator = separator ?? (context) => SizedBox(height: separatorHeight ?? 10);
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    for (var i = 0; i < this.children.length; i++) {
      children.add(this.children[i]);
      if (i < this.children.length - 1)
        children.add(separator!(context));
    }
    return Column(
      mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.start,
      children: children,
    );
  }
}
