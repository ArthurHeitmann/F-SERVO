
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/expandOnHover.dart';
import '../../misc/puidDraggable.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/UnderlinePropTextField.dart';

class ObjIdEditor extends ChangeNotifierWidget {
  final StringProp objId;
  final HexProp? entityId;

  ObjIdEditor({ super.key, required XmlProp objId, this.entityId })
    : objId = objId.value as StringProp,
    super(notifier: objId);

  @override
  State<ObjIdEditor> createState() => _ObjIdEditorState();
}

String _getAssetPath(String modeName) {
  return "assets/entityThumbnails/$modeName.png";
}

class _ObjIdEditorState extends ChangeNotifierState<ObjIdEditor> { @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        optionalPuidDraggable(
          child: ObjIdIcon(objId: widget.objId)
        ),
        const SizedBox(width: 8),
        UnderlinePropTextField(prop: widget.objId),
      ],
    );
  }

  Widget optionalPuidDraggable({ required Widget child }) {
    if (widget.entityId == null)
      return child;
    return PuidDraggable(
      code: "app::EntityLayout",
      id: widget.entityId!.value,
      name: widget.objId.value,
      child: child,
    );
  }
}

class ObjIdIcon extends ChangeNotifierWidget {
  final StringProp objId;
  final double size;

  ObjIdIcon({ super.key, required this.objId, this.size = 45 }) : super(notifier: objId);
  @override
  State<ObjIdIcon> createState() => _ObjIdIconState();
}

class _ObjIdIconState extends ChangeNotifierState<ObjIdIcon> {
  @override
  Widget build(BuildContext context) {
    return ExpandOnHover(
      child: Image(
        image: AssetImage(_getAssetPath(widget.objId.value)),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Material(
          color: Colors.transparent,
          child: Text(
            "?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: getTheme(context).textColor!.withOpacity(0.333),
            ),
          ),
        ),
      ),
    );
  }
}
