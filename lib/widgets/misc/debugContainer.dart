

import 'package:flutter/material.dart';

class DebugContainer extends StatelessWidget {
  final Widget child;

  const DebugContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
      ),
      child: child,
    );
  }
}
