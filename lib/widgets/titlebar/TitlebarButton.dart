
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../utils.dart';

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
  // bool isHovered = false;

  AnimationController? colorAnimationController;
  Animation<Color?>? colorAnimation;

  void initAnimations() {
    colorAnimationController ??= AnimationController(
      duration: const Duration(milliseconds: 125),
      vsync: this,
    );

    colorAnimation ??= ColorTween(
      begin: getTheme(context).titleBarButtonDefaultColor,
      end: widget.primaryColor,
    ).animate(colorAnimationController!);
  }

  @override
  void dispose() {
    colorAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    initAnimations();

    return AnimatedBuilder(
      animation: colorAnimationController!,
      builder: (context, child) => MouseRegion(
        onHover: (_) => colorAnimationController!.forward(),
        onExit: (_) => colorAnimationController!.reverse(),
        child: TextButton.icon(
          icon: Icon(
            widget.icon,
            color: colorAnimation!.value,
            size: titleBarHeight * 0.75,
          ),
          label: Text(""),
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: colorAnimation!.value,
          ),
        ),
      ),
    );
  }
}
