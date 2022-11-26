
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../widgets/theme/customTheme.dart';
import '../../utils/utils.dart';

/*
Per file[uuid] one or zero selected (has uuid + XmlProp)
*/

class _SelectedData {
  final String uuid;
  final XmlProp prop;
  final void Function() onDispose;

  _SelectedData(this.uuid, this.prop, this.onDispose) {
    prop.onDisposed.addListener(onDispose);
  }

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

  void select(OpenFileId id, XmlProp prop) {
    _selectedData[id]?.dispose();
    _selectedData[id] = _SelectedData(prop.uuid, prop, () {
      if (_selectedData[id]?.uuid == prop.uuid)
        _selectedData[id] = null;
      if (active.value?.uuid == prop.uuid)
        active.value = null;
    });
    if (id == areasManager.activeArea?.currentFile?.uuid)
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
    if (id == areasManager.activeArea?.currentFile?.uuid)
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
    var id = areasManager.activeArea?.currentFile?.uuid;
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
  final OpenFileId id;
  final XmlProp prop;
  final Widget child;

  SelectableWidget({
    super.key,
    this.color,
    this.borderRadius,
    required this.prop,
    required this.child
  }) : id = prop.file!,
       super(notifier: selectable.active);

  @override
  State<SelectableWidget> createState() => _SelectableWidgetState();
}

class _SelectableWidgetState<T> extends ChangeNotifierState<SelectableWidget> {
  void select() {
    if (!mounted)
      return;
    selectable.select(widget.id, widget.prop);
  }

  void deselect() {
    if (!mounted)
      return;
    selectable.deselect(widget.prop.uuid);
  }
  
  @override
  Widget build(BuildContext context) {
    Color borderColor;
    if (selectable.isSelected(widget.prop.uuid))
      borderColor = widget.color ?? getTheme(context).selectedColor!;
    else
      borderColor = Colors.transparent;
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
                border: Border.all(color: borderColor, width: 2),
                borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        GestureDetector(
            onTap: () {
              if ((isCtrlPressed() || isShiftPressed()) && selectable.isSelected(widget.prop.uuid))
                selectable.deselect(widget.prop.uuid);
              else
                selectable.select(widget.id, widget.prop);
            },
            child: widget.child,
          ),
      ],
    );
  }
}
