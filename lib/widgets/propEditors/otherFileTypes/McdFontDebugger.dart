
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../utils/assetDirFinder.dart';
import '../../../utils/utils.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/otherFileTypes/McdData.dart';


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
      var imgBytes = await File(widget.texturePath).readAsBytes();
      image = Image.memory(imgBytes, fit: BoxFit.contain);
      uiImage = await decodeImageFromList(imgBytes);
      imageSize = SizeInt(uiImage!.width, uiImage!.height);
      if (mounted)
        setState(() {});
    }
    else if (widget.texturePath.endsWith(".dds") || widget.texturePath.endsWith(".wtp")) {
      if (!await hasMagickBins()) {
        showToast("Can't load texture because ImageMagick is not found.");
        return;
      }
      var result = await Process.run(
        magickBinPath!,
        ["DDS:${widget.texturePath}", "PNG:-"],
        stdoutEncoding: null,
      );
      if (result.exitCode != 0) {
        showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
        return;
      }
      var imageBytes = Uint8List.fromList(result.stdout as List<int>);
      image = Image.memory(imageBytes, fit: BoxFit.contain);
      uiImage = await decodeImageFromList(imageBytes);
      imageSize = SizeInt(uiImage!.width, uiImage!.height);
      if (mounted)
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (image == null) {
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
        return Center(
          child: SizedBox(
            width: areaWidth,
            height: areaHeight,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 10,
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
                          left: sym.x / imageSize!.width * areaWidth,
                          top: sym.y / imageSize!.height * areaHeight,
                          width: sym.width / imageSize!.width * areaWidth,
                          height: sym.height / imageSize!.height * areaHeight,
                          child: Tooltip(
                            waitDuration: const Duration(milliseconds: 250),
                            message: "char: ${sym.char} (${sym.code})\nfontID: ${sym.fontId}\nfontHeight: ${font.fontHeight}\nfontBelow: ${font.fontBelow}",
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
        var x = sym.x / imageSize.width * areaSize.width;
        var y = sym.y / imageSize.height * areaSize.height;
        var width = sym.width / imageSize.width * areaSize.width;
        var height = sym.height / imageSize.height * areaSize.height;
        var rect = Rect.fromLTWH(x, y, width, height);
        canvas.drawRect(rect, paint);

        y += height + font.fontBelow / imageSize.height * areaSize.height;
        canvas.drawLine(Offset(x, y), Offset(x + width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
