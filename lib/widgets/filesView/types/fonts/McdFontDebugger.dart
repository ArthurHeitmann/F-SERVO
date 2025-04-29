
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../fileTypeUtils/textures/ddsConverter.dart';
import '../../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../../fileTypeUtils/wta/wtaReader.dart';
import '../../../../stateManagement/openFiles/types/McdFileData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../../fileSystem/FileSystem.dart';


class McdFontDebugger extends ChangeNotifierWidget {
  final String texturePath;
  final List<McdFont> fonts;

  McdFontDebugger({
    super.key,
    required this.texturePath,
    required this.fonts,
  }) : super(notifier: McdData.fontChanges);

  @override
  State<McdFontDebugger> createState() => _McdFontDebuggerState();
}

class _McdFontDebuggerState extends ChangeNotifierState<McdFontDebugger> {
  Image? image;
  ui.Image? uiImage;
  SizeInt? imageSize;

  @override
  void initState() {
    super.initState();

    loadImage();
  }

  @override
  void onNotified() {
    loadImage();
    super.onNotified();
  }

  Future<void> loadImage() async {
    if (widget.texturePath.endsWith(".png") || widget.texturePath.endsWith(".jpg")) {
      var imgBytes = await FS.i.read(widget.texturePath);
      image = Image.memory(imgBytes, fit: BoxFit.contain);
      uiImage = await decodeImageFromList(imgBytes);
      imageSize = SizeInt(uiImage!.width, uiImage!.height);
      if (mounted)
        setState(() {});
    }
    else if (widget.texturePath.endsWith(".dds") || widget.texturePath.endsWith(".wtp")) {
      var imageBytes = await texToPng(widget.texturePath);
      if (imageBytes == null)
        return;
      image = Image.memory(imageBytes, fit: BoxFit.contain);
      uiImage = await decodeImageFromList(imageBytes);
      imageSize = SizeInt(uiImage!.width, uiImage!.height);
      if (mounted)
        setState(() {});
    }
    else if (widget.texturePath.endsWith(".wtb")) {
      var wtbBytes = await ByteDataWrapper.fromFile(widget.texturePath);
      var wtb = WtaFile.read(wtbBytes);
      wtbBytes.position = wtb.textureOffsets[0];
      var textureBytes = wtbBytes.asUint8List(wtb.textureSizes[0]);
      image = Image.memory(textureBytes, fit: BoxFit.contain);
      uiImage = await decodeImageFromList(textureBytes);
      imageSize = SizeInt(uiImage!.width, uiImage!.height);
      if (mounted)
        setState(() {});
    }
    else {
      showToast("Unsupported texture format ${widget.texturePath}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (image == null || imageSize == null) {
          return const SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          );
        }

        var squareSize = min(constraints.maxWidth, constraints.maxHeight);
        var areaWidth = squareSize;
        var areaHeight = squareSize;
        if (imageSize!.width != imageSize!.height) {
          if (imageSize!.width > imageSize!.height)
            areaHeight = squareSize * imageSize!.height / imageSize!.width;
          else
            areaWidth = squareSize * imageSize!.width / imageSize!.height;
        }
        var symbolsCount = sum(widget.fonts.map((e) => e.supportedSymbols.length));
        return InteractiveViewer(
          minScale: 1,
          maxScale: 10,
          child: Center(
            child: SizedBox(
              width: areaWidth,
              height: areaHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SimpleFontViewPainter(
                        image: uiImage!,
                        imageSize: imageSize!,
                        areaSize: SizeInt(areaWidth.round(), areaHeight.round()),
                        fonts: widget.fonts,
                      ),
                    ),
                  ),
                  if (symbolsCount < 1024)
                    for (var font in widget.fonts)
                      for (var sym in font.supportedSymbols.values)
                        Positioned(
                          left: sym.uv1.dx * areaWidth,
                          top: sym.uv1.dy * areaHeight,
                          width: (sym.uv2.dx - sym.uv1.dx) * areaWidth,
                          height: (sym.uv2.dy - sym.uv1.dy) * areaHeight,
                          child: Tooltip(
                            waitDuration: const Duration(milliseconds: 250),
                            message: 
                              "char: ${sym.char} (${sym.code})\n"
                              "fontID: ${sym.fontId}\n"
                              "fontHeight: ${font.fontHeight}\n"
                              "tex size: ${sym.getWidth()}x${sym.getHeight()}\n"
                              "rendered size: ${sym.renderedSize.width.round()}x${sym.renderedSize.height.round()}"
                              ,
                          ),
                        ),
                ]
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SimpleFontViewPainter extends CustomPainter {
  final ui.Image image;
  final SizeInt imageSize;
  final SizeInt areaSize;
  final List<McdFont> fonts;

  _SimpleFontViewPainter({
    required this.image,
    required this.imageSize,
    required this.areaSize,
    required this.fonts,
  }) : super(repaint: McdData.fontChanges);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    var areaRect = Rect.fromLTWH(0, 0, areaSize.width.toDouble(), areaSize.height.toDouble());
    canvas.drawRect(areaRect, paint);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, imageSize.width.toDouble(), imageSize.height.toDouble()), areaRect, Paint());

    for (var font in fonts) {
      for (var sym in font.supportedSymbols.values) {
        var x = sym.uv1.dx * areaSize.width;
        var y = sym.uv1.dy * areaSize.height;
        var width = (sym.uv2.dx - sym.uv1.dx) * areaSize.width;
        var height = (sym.uv2.dy - sym.uv1.dy) * areaSize.height;
        var rect = Rect.fromLTWH(x, y, width, height);
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
