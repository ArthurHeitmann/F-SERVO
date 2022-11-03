
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../ChangeNotifierWidget.dart';
import 'McdData.dart';


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
      var decodedImage = await decodeImageFromList(imgBytes);
      imageSize = SizeInt(decodedImage.width, decodedImage.height);
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
      var decodedImage = await decodeImageFromList(imageBytes);
      imageSize = SizeInt(decodedImage.width, decodedImage.height);
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
        return Center(
          child: SizedBox(
            width: areaWidth,
            height: areaHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.lightBlue, width: 0.5),
                    ),
                    child: image!
                  ),
                ),
                for (var font in widget.fonts)
                  for (var sym in font.supportedSymbols.values)
                    ...[
                      Positioned(
                        left: sym.x / imageSize!.width * areaWidth,
                        top: sym.y / imageSize!.height * areaHeight,
                        width: sym.width / imageSize!.width * areaWidth,
                        height: sym.height / imageSize!.height * areaHeight,
                        child: Tooltip(
                          waitDuration: const Duration(milliseconds: 250),
                          message: "char: ${sym.char} (${sym.code})\nfontID: ${sym.fontId}\nfontHeight: ${font.fontHeight}\nfontBelow: ${font.fontBelow}",
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.lightBlue, width: 0.5),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: sym.x / imageSize!.width * areaWidth,
                        top: (sym.y + sym.height + font.fontBelow) / imageSize!.height * areaHeight,
                        width: sym.width / imageSize!.width * areaWidth,
                        child: const Divider(
                          color: Colors.lightBlue,
                          thickness: 0.25,
                          height: 0.25,
                        ),
                      ),
                    ]
              ]
            ),
          ),
        );
      },
    );
  }
}
