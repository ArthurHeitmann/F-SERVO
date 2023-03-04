
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
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
    return optionalPuidDraggable(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          ObjIdIcon(objId: widget.objId),
          const SizedBox(width: 8),
          UnderlinePropTextField(prop: widget.objId),
        ],
      ),
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
  Future<bool>? _isAssetValid;
  Timer? expandTimer;
  OverlayEntry? overlayEntry;
  BuildContext? imgContext;

  Future<bool> isAssetValid(String asset) async {
    try {
      await rootBundle.load(asset);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    _isAssetValid = isAssetValid(_getAssetPath(widget.objId.value));
    super.initState();
  }

  @override
  void onNotified() {
    _isAssetValid = isAssetValid(_getAssetPath(widget.objId.value));
    super.onNotified();
  }

  void _expand() {
    // add overlay with expanded image
    var overlayState = Overlay.of(context);
    var renderBox = imgContext!.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    var size = renderBox.size;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy,
        width: size.width,
        height: size.height,
        child: _ExpandedImage(
          smallSize: widget.size,
          future: _isAssetValid,
          assetPath: _getAssetPath(widget.objId.value),
          onDismiss: () {
            overlayEntry!.remove();
            overlayEntry = null;
          },
        ),
      ),
    );
    overlayState.insert(overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (overlayEntry!= null)
          return;
        if (expandTimer != null)
          expandTimer!.cancel();
        expandTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted)
            _expand();
        });
      },
      onExit: (_) {
        if (expandTimer != null)
          expandTimer!.cancel();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        child: Builder(
          builder: (context) {
            imgContext = context;
            return _ObjIdIconFB(
              key: Key(widget.objId.value),
              future: _isAssetValid,
              assetPath: _getAssetPath(widget.objId.value),
            );
          }
        ),
      ),
    );
  }
}

class _ObjIdIconFB extends StatelessWidget {
  final Future<bool>? future;
  final String assetPath;
  
  const _ObjIdIconFB({ super.key, required this.future , required this.assetPath });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data == true) {
            return Image.asset(assetPath, width: 50, height: 50);
          } else {
            return Text(
              "?",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: getTheme(context).textColor!.withOpacity(0.333),
              ),
            );
          }
        } else {
          return const SizedBox();
        }
      }
    );
  }
}

class _ExpandedImage extends StatefulWidget {
  final double smallSize;
  final Future<bool>? future;
  final String assetPath;
  final VoidCallback onDismiss;

  const _ExpandedImage({ required this.smallSize, required this.future, required this.assetPath, required this.onDismiss });

  @override
  State<_ExpandedImage> createState() => __ExpandedImageState();
}

class __ExpandedImageState extends State<_ExpandedImage> {
  bool isExpanded = false;
  Timer? dismissTimer;
  Timer? fallbackDismissTimer;

  static const _expandSize = 200;
  static const _expandDuration = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    fallbackDismissTimer = Timer(const Duration(seconds: 15), dismiss);
    waitForNextFrame().then((_) {
      if (mounted)
        setState(() => isExpanded = true);
    });
  }

  @override
  void dispose() {
    dismiss();
    super.dispose();
  }

  void dismiss() async {
    if (!isExpanded)
      return;
    fallbackDismissTimer?.cancel();
    if (dismissTimer != null)
      dismissTimer!.cancel();
    dismissTimer = Timer(const Duration(milliseconds: 500), () async {
      isExpanded = false;
      setState(() {});
      await waitForNextFrame();
      await Future.delayed(_expandDuration);
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (dismissTimer != null)
          dismissTimer!.cancel();
      },
      onExit: (_)  => dismiss(),
      child: AnimatedScale(
        scale: isExpanded ? _expandSize / widget.smallSize : 1,
        duration: _expandDuration,
        child: _ObjIdIconFB(
          key: Key(widget.assetPath),
          future: widget.future,
          assetPath: widget.assetPath,
        ),
      ),
    );
  }
}
