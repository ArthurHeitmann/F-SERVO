
import 'package:flutter/material.dart';

import '../../misc/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';

class BoolPropIconButton extends ChangeNotifierWidget {
  final ValueProp<bool> prop;
  final IconData icon;
  final String? tooltip;

  BoolPropIconButton({super.key, required this.prop, required this.icon, this.tooltip}) : super(notifier: prop);

  @override
  State<BoolPropIconButton> createState() => _BoolPropSliderState();
}

class _BoolPropSliderState extends ChangeNotifierState<BoolPropIconButton> {
  @override
  Widget build(BuildContext context) {
    return optionalTooltip(
      child: InkWell(
        onTap: () => widget.prop.value = !widget.prop.value,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Icon(
            widget.icon,
            color: widget.prop.value
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            size: 18,
            semanticLabel: widget.tooltip,
          ),
        ),
      ),
    );
  }

  Widget optionalTooltip({required Widget child}) {
    if (widget.tooltip == null)
      return child;
    return Tooltip(
      message: widget.tooltip!,
      waitDuration: const Duration(milliseconds: 750),
      child: child,
    );
  }
}
