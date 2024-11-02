
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;


import '../theme/customTheme.dart';

class GameLogo extends StatefulWidget {
  final Size size;

  const GameLogo({super.key, required this.size});

  @override
  State<GameLogo> createState() => _GameLogoState();
}

class _GameLogoState extends State<GameLogo> {
  late Future<ui.Image> _img;

  @override
  void initState() {
    super.initState();
    _img = rootBundle.load("assets/images/desperado.png")
      .then((bytes) => decodeImageFromList(bytes.buffer.asUint8List()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _img,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return SizedBox(
            width: widget.size.width,
            height: widget.size.height,
          );
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            var image = snapshot.data!;
            return ImageShader(
              image,
              TileMode.repeated,
              TileMode.repeated,
              Matrix4.diagonal3Values(widget.size.width / image.width, widget.size.height / image.height, 1).storage,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Container(
              width: widget.size.width - 1,
              height: widget.size.height - 1,
              color: getTheme(context).textColor?.withOpacity(0.85),
            ),
          ),
        );
      },
    );
  }
}
