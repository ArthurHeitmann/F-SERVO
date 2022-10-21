
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';

class SmallButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final BoxConstraints? constraints;
  
  const SmallButton({super.key, required this.child, required this.onPressed, this.constraints});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).formElementBgColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: constraints,
      child: MaterialButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: child
      ),
    );
  }
}
