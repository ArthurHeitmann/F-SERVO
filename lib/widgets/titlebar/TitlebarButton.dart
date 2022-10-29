
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../utils/utils.dart';

class TitleBarButton extends StatefulWidget {
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
  State<TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<TitleBarButton> with SingleTickerProviderStateMixin {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: TextButton.icon(
        icon: Icon(
          widget.icon,
          color: isHovered ? widget.primaryColor : getTheme(context).textColor,
          size: titleBarHeight * 0.75,
        ),
        label: const Text(""),
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isHovered ? widget.primaryColor : getTheme(context).textColor,
        ),
      ),
    );
  }
}
