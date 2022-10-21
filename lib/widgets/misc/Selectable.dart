
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../utils.dart';

class _SelectedData<T> {
  final T? data;
  final _SelectableWidgetState state;

  _SelectedData(this.data, this.state);
}

class _Selectable extends ChangeNotifier {
  final Map<dynamic, Map<Type, _SelectedData>> _selectedData = {};

  void select<T>(dynamic area, T? data, _SelectableWidgetState state) {
    if (!_selectedData.containsKey(area))
      _selectedData[area] = {};
    else if (_selectedData[area]![T]?.state == state)
      return;

    _selectedData[area]![T]?.state.deselect();
    _selectedData[area]![T]?.state.onDispose = null;

    _selectedData[area]![T] = _SelectedData(data, state);
    state.onDispose = () => _selectedData.remove(T);
    state.select();

    notifyListeners();
  }

  void deselect<T>(dynamic area) {
    if (!_selectedData.containsKey(area) || !_selectedData[area]!.containsKey(T))
      return;

    _selectedData[area]![T]?.state.deselect();
    _selectedData[area]![T]?.state.onDispose = null;
    _selectedData[area]!.remove(T);

    notifyListeners();
  }

  void deselectAll(dynamic area) {
    _selectedData[area]?.forEach((key, value) {
      value.state.deselect();
      value.state.onDispose = null;
    });
    _selectedData.remove(area);

    notifyListeners();
  }

  T? get<T>(dynamic area) {
    return _selectedData[area]?[T]?.data;
  }
}

final  selectable = _Selectable();

class SelectableWidget<T> extends StatefulWidget {
  final dynamic area;
  final T? data;
  final Color? color;
  final Widget child;

  const SelectableWidget({super.key, this.area, this.data, this.color, required this.child});

  @override
  State<SelectableWidget> createState() => _SelectableWidgetState<T>();
}

class _SelectableWidgetState<T> extends State<SelectableWidget> {
  bool isSelected = false;
  VoidCallback? onDispose;

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }  

  void select() {
    if (!mounted)
      return;
    setState(() => isSelected = true);
  }

  void deselect() {
    if (!mounted)
      return;
    setState(() => isSelected = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -4,
          right: -4,
          left: -4,
          bottom: -4,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 125),
              decoration: BoxDecoration(
                border: isSelected
                  ? Border.all(color: widget.color ?? getTheme(context).selectedColor!, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        GestureDetector(
            onTap: () {
              if ((isCtrlPressed() || isShiftPressed()) && isSelected)
                selectable.deselect<T>(widget.area);
              else
                selectable.select<T>(widget.area, widget.data, this);
            },
            child: widget.child,
          ),
      ],
    );
  }
}
