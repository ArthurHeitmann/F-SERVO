
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';

class TitleBarButton extends StatefulWidget {
  final IconData icon;
  final void Function() onPressed;
  final Color primaryColor;
  static const _defaultColor = Color.fromRGBO(239, 239, 239, 1);

  const TitleBarButton({
    Key? key, 
    required this.icon,
    required this.onPressed,
    this.primaryColor = _defaultColor
  }) : super(key: key);

  @override
  State<TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<TitleBarButton> with SingleTickerProviderStateMixin {
  // bool isHovered = false;

  late AnimationController colorAnimationController;
  late Animation<Color?> colorAnimation;

  @override
  void initState() {
    colorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 125),
      vsync: this,
    );

    colorAnimation = ColorTween(
      begin: TitleBarButton._defaultColor,
      end: widget.primaryColor,
    ).animate(colorAnimationController);

    super.initState();
  }

  @override
  void dispose() {
    colorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: colorAnimationController,
      builder: (context, child) => MouseRegion(
        // onEnter: (_) => setState(() => isHovered = true),
        // onExit: (_) => setState(() => isHovered = false),
        onHover: (_) => colorAnimationController.forward(),
        onExit: (_) => colorAnimationController.reverse(),
        child: TextButton.icon(
          icon: Icon(widget.icon, color: colorAnimation.value),
          label: Text(""),
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
          //   primary: isHovered ? widget.activeColor : TitleBarButton._defaultColor,
            primary: colorAnimation.value,
          ),
        ),
      ),
    );
  }
}
