
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import 'McdData.dart';


class McdFontDebugger extends StatefulWidget {
  final String texturePath;
  final List<McdFont> fonts;

  const McdFontDebugger({ super.key, required this.texturePath, required this.fonts });

  @override
  State<McdFontDebugger> createState() => _McdFontDebuggerState();
}

class _McdFontDebuggerState extends State<McdFontDebugger> {
  Image? image;
  SizeInt? imageSize;

  @override
  void initState() {
    super.initState();
    
    if (widget.texturePath.endsWith(".png") || widget.texturePath.endsWith(".jpg")) {
      () async {
        var imgBytes = await File(widget.texturePath).readAsBytes();
        image = Image.memory(imgBytes, fit: BoxFit.contain);
        var decodedImage = await decodeImageFromList(imgBytes);
        imageSize = SizeInt(decodedImage.width, decodedImage.height);
        setState(() {});
      }();
    }
    else if (widget.texturePath.endsWith(".dds") || widget.texturePath.endsWith(".wtp")) {
      () async {
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
      }();
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
        return Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: squareSize, height: squareSize),
              child: image!
            ),
            for (var font in widget.fonts)
              for (var sym in font.supportedSymbols.values)
              Positioned(
                left: sym.x / imageSize!.width * squareSize,
                top: sym.y / imageSize!.height * squareSize,
                width: sym.width / imageSize!.width * squareSize,
                height: sym.height / imageSize!.height * squareSize,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.lightBlue),
                  ),
                ),
              )
          ]
        );
      },
    );
  }
}
