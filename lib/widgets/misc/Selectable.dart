
import 'package:flutter/material.dart';

import '../../keyboardEvents/intents.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../utils/Disposable.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import 'ChangeNotifierWidget.dart';

/*
Per file[uuid] one or zero selected (has uuid + XmlProp)
*/

typedef ChildKeyboardActionCallback = void Function(ChildKeyboardActionType actionType);

class _SelectedData implements Disposable {
  final String uuid;
  final XmlProp prop;
  final void Function() onDispose;
  final ChildKeyboardActionCallback? onKeyboardAction;

  _SelectedData(this.uuid, this.prop, this.onDispose, this.onKeyboardAction) {
    prop.onDisposed.addListener(onDispose);
  }

  @override
  void dispose() {
    prop.onDisposed.removeListener(onDispose);
  }
}

class _Selectable {
  final Map<OpenFileId, _SelectedData?> _selectedData = {};
  final active = ValueNotifier<_SelectedData?>(null);

  _Selectable() {
    areasManager.subEvents.addListener(_onAreaChanges);
  }

  void select(OpenFileId id, XmlProp prop, [ChildKeyboardActionCallback? onKeyboardAction]) {
    _selectedData[id]?.dispose();
    _selectedData[id] = _SelectedData(prop.uuid, prop, () {
      if (_selectedData[id]?.uuid == prop.uuid)
        _selectedData[id] = null;
      if (active.value?.uuid == prop.uuid)
        active.value = null;
    }, onKeyboardAction);
    if (id == areasManager.activeArea.value?.currentFile.value?.uuid)
      active.value = _selectedData[id];
    active.value = _selectedData[id];
  }

  void deselect(String uuid) {
    if (active.value?.uuid == uuid)
      active.value = null;
    var ids = _selectedData.keys.where((id) => _selectedData[id]?.uuid == uuid);
    var id = ids.isNotEmpty ? ids.first : null;
    if (id == null)
      return;
    if (_selectedData[id]?.uuid != uuid)
      return;
    _selectedData[id]?.dispose();
    _selectedData[id] = null;
    if (id == areasManager.activeArea.value?.currentFile.value?.uuid)
      active.value = null;
  }

  void deselectFile(OpenFileId id) {
    if (_selectedData[id]?.uuid == active.value?.uuid)
      active.value = null;
    _selectedData[id]?.dispose();
    _selectedData[id] = null;
  }

  bool isSelected(String uuid) => _selectedData.values.any((e) => e?.uuid == uuid);

  void _onAreaChanges() {
    var id = areasManager.activeArea.value?.currentFile.value?.uuid;
    if (id == null)
      active.value = null;
    else
      active.value = _selectedData[id];
  }
}

final  selectable = _Selectable();

class SelectableWidget extends ChangeNotifierWidget {
  final Color? color;
  final BorderRadius? borderRadius;
  final double? padding;
  final OpenFileId id;
  final XmlProp prop;
  final ChildKeyboardActionCallback? onKeyboardAction;
  final Widget child;

  SelectableWidget({
    super.key,
    this.color,
    this.borderRadius,
    this.padding,
    required this.prop,
    this.onKeyboardAction,
    required this.child
  }) : id = prop.file!,
       super(notifier: selectable.active);

  @override
  State<SelectableWidget> createState() => _SelectableWidgetState();
}

class _SelectableWidgetState<T> extends ChangeNotifierState<SelectableWidget> {
  @override
  Widget build(BuildContext context) {
    Color borderColor = selectable.isSelected(widget.prop.uuid)
      ? widget.color ?? getTheme(context).selectedColor!
      : Colors.transparent;
    double padding = widget.padding != null ? -widget.padding! : -4;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: padding,
          right: padding,
          left: padding,
          bottom: padding,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 125),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 2),
                borderRadius: widget.borderRadius ?? BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if ((isCtrlPressed() || isShiftPressed()) && selectable.isSelected(widget.prop.uuid))
              selectable.deselect(widget.prop.uuid);
            else
              selectable.select(widget.id, widget.prop, widget.onKeyboardAction);
          },
          child: widget.child,
        ),
      ],
    );
  }
}
