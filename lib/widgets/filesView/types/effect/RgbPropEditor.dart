
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../theme/customTheme.dart';
import 'ColorPicker.dart';
import 'RgbColorModeFields.dart';

class RgbPropEditor extends StatefulWidget {
  final VectorProp prop;
  final bool showTextFields;

  const RgbPropEditor({super.key, required this.prop, this.showTextFields = true});

  @override
  State<RgbPropEditor> createState() => _RgbPropEditorState();
}

class _RgbPropEditorState extends State<RgbPropEditor> {
  OverlayEntry? overlayEntry;
  final List<Rect> overlayRectangles = [];
  bool hasClickedOutside = false;

  @override
  void dispose() {
    overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (_) => showColorPicker(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChangeNotifierBuilder(
            notifier: widget.prop,
            builder: (context) {
              double maxVal = widget.prop
                .map((e) => e.value.toDouble())
                .reduce(max);
              maxVal = max(maxVal, 1.0);
              var color = Color.fromARGB(
                255,
                (widget.prop[0].value.toDouble() / maxVal * 255).toInt(),
                (widget.prop[1].value.toDouble() / maxVal * 255).toInt(),
                (widget.prop[2].value.toDouble() / maxVal * 255).toInt(),
              );
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    boxShadow: [
                      if (maxVal > 1)
                        BoxShadow(color: color, blurRadius: 3 * maxVal, spreadRadius: 1 * maxVal)
                    ],
                    borderRadius: BorderRadius.circular(5),
                    color: color,
                    border: Border.all(
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            }
          ),
          if (widget.showTextFields) ...[
            const SizedBox(width: 10),
            Expanded(
              child: RgbColorModeFields(rgb: widget.prop)
            ),
          ],
        ],
      ),
    );
  }

  void showColorPicker(BuildContext context) {
    if (overlayEntry != null) {
      return;
    }
    const width = 350.0;
    const height = 200.0;
    var windowSize = MediaQuery.of(context).size;
    var renderBox = context.findRenderObject() as RenderBox;
    var selfPos = renderBox.localToGlobal(Offset.zero);
    var selfSize = renderBox.size;
    var top = selfPos.dy - height - 4 > 0
      ? selfPos.dy - height
      : selfPos.dy + selfSize.height;
    var left = selfPos.dx + width + 25 < windowSize.width
      ? selfPos.dx
      : windowSize.width - width - 25;
    var selfRect = Rect.fromLTWH(selfPos.dx, selfPos.dy, selfSize.width, selfSize.height);
    overlayRectangles.clear();
    // main rectangle
    overlayRectangles.add(Rect.fromLTWH(left, top, width, height));
    overlayRectangles.add(selfRect);
    // drop down 
    overlayRectangles.add(Rect.fromLTWH(
      selfRect.left + (widget.showTextFields ? 18 : 4),
      (widget.showTextFields ? selfRect.bottom : top + height) - 8,
      60,
      85
    ));
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (event) {
                if (overlayRectangles.every((rect) => !rect.contains(event.position))) {
                  hasClickedOutside = true;
                }
              },
              onPointerUp: (event) {
                if (hasClickedOutside && overlayRectangles.every((rect) => !rect.contains(event.position))) {
                  overlayEntry?.remove();
                  overlayEntry = null;
                  setState(() {});
                }
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: top,
            left: left,
            width: width,
            height: height,
            child: Material(
              color: getTheme(context).sidebarBackgroundColor,
              elevation: 8,
              child: ColorPicker(
                rgb: widget.prop,
                showTextFields: !widget.showTextFields,
              ),
            ),
          ),
          // debug visualize rectangles
          // for (var (i, rect) in overlayRectangles.indexed)
          //   Positioned(
          //     top: rect.top,
          //     left: rect.left,
          //     width: rect.width,
          //     height: rect.height,
          //     child: Container(
          //       decoration: BoxDecoration(
          //         border: Border.all(color: Colors.red),
          //       ),
          //     ),
          //   ),
        ],
      )
    );
    Overlay.of(context).insert(overlayEntry!);
    setState(() {});
  }
}
