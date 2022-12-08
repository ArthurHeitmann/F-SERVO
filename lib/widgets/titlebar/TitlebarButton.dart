
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../utils/utils.dart';
import '../misc/onHoverBuilder.dart';

class TitleBarButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onPressed;
  final Color? primaryColor;

  const TitleBarButton({
    Key? key, 
    required this.icon,
    required this.onPressed,
    this.primaryColor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnHoverBuilder(
      builder: (context, isHovering) => TextButton.icon(
        icon: Icon(
          icon,
          color: isHovering ? primaryColor : getTheme(context).textColor,
          size: titleBarHeight * 0.75,
        ),
        label: const Text(""),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isHovering ? primaryColor : getTheme(context).textColor,
        ),
      ),
    );
  }
}
