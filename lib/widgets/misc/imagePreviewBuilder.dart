
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../fileTypeUtils/textures/ddsConverter.dart';
import '../../utils/utils.dart';

enum ImagePreviewState {
  loading,
  loaded,
  notFound,
  error,
}

class ImagePreviewBuilder extends StatefulWidget {
  final String path;
  final int? maxHeight;
  final Widget Function(BuildContext context, Uint8List? data, ImagePreviewState state) builder;

  const ImagePreviewBuilder({
    super.key,
    required this.path,
    this.maxHeight,
    required this.builder,
  });

  @override
  State<ImagePreviewBuilder> createState() => _ImagePreviewBuilderState();
}

class _ImagePreviewBuilderState extends State<ImagePreviewBuilder> {
  String lastPath = "";
  late Future<Uint8List?> image;
  bool exists = true;

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  void checkForChanges() {
    if (lastPath != widget.path) {
      loadImage();
    }
  }

  Future<void> loadImage() async {
    lastPath = widget.path;
    image = Future.value(null);
    setState(() {});
    if (!await File(widget.path).exists()) {
      exists = false;
      return;
    }
    exists = true;
    var sw = Stopwatch()..start();
    image = texToPng(widget.path, maxHeight: widget.maxHeight, verbose: false)
      ..then((_) {
        debugOnly(() => print("Loaded image in ${sw.elapsedMilliseconds}ms"));
      });
    setState(() {});
  }

  ImagePreviewState getImageState(bool hasData, bool hasError) {
    if (!exists)
      return ImagePreviewState.notFound;
    if (hasError)
      return ImagePreviewState.error;
    if (!hasData)
      return ImagePreviewState.loading;
    return ImagePreviewState.loaded;
  }

  @override
  Widget build(BuildContext context) {
    checkForChanges();
    return FutureBuilder<Uint8List?>(
      future: image,
      builder: (context, snapshot) {
        return widget.builder(
          context,
          snapshot.data,
          getImageState(snapshot.hasData, snapshot.hasError)
        );
      },
    );
  }
}
