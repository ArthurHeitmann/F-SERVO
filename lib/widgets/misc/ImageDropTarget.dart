import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../fileSystem/FileSystem.dart';
import '../theme/customTheme.dart';
import 'dropTargetBuilder.dart';
import 'imagePreviewBuilder.dart';
import 'onHoverBuilder.dart';

class ImageDropTarget extends StatefulWidget {
  final String imgPath;
  final BoxConstraints constraints;
  final void Function(String paths) onDrop;
  final Widget Function(BuildContext context, Uint8List image)? imageBuilder;

  const ImageDropTarget({
    super.key,
    required this.imgPath,
    required this.constraints,
    required this.onDrop,
    this.imageBuilder,
  });

  @override
  State<ImageDropTarget> createState() => _ImageDropTargetState();
}

class _ImageDropTargetState extends State<ImageDropTarget> {
  late final PageStorageKey imageKey;

  @override
  void initState() {
    super.initState();
    imageKey = PageStorageKey("imgPreview-${widget.imgPath}");
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: widget.constraints,
      child: DropTargetBuilder(
        onDrop: (paths) => widget.onDrop(paths.first),
        builder: (context, isDropping) {
          return IndexedStack(
            index: isDropping ? 1 : 0,
            sizing: StackFit.expand,
            children: [
              GestureDetector(
                key: imageKey,
                onTap: pickSrcFile,
                child: OnHoverBuilder(
                  cursor: SystemMouseCursors.click,
                  builder: (context, isHovering) {
                    return AnimatedScale(
                      scale: isHovering ? 1.02 : 1,
                      duration: const Duration(milliseconds: 100),
                      child: ImagePreviewBuilder(
                        path: widget.imgPath,
                        maxHeight: 50,
                        builder: (context, data, state) {
                          return Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 5),
                              Stack(
                                children: [
                                  if (state == ImagePreviewState.loading || state == ImagePreviewState.notFound)
                                    const Icon(Icons.file_download_outlined, size: 24)
                                  else if (state == ImagePreviewState.error)
                                    const Icon(Icons.error_outline, size: 24)
                                  else if (state == ImagePreviewState.loaded)
                                    widget.imageBuilder?.call(context, data!) ?? Image.memory(data!),
                                  // if (isHovering && state == ImagePreviewState.loaded)
                                  //    Positioned.fill(
                                  //      child: Align(
                                  //         alignment: Alignment.center,
                                  //         child: Icon(
                                  //           Icons.file_download_outlined,
                                  //           color: getTheme(context).textColor,
                                  //           size: 30,
                                  //           shadows: [
                                  //             Shadow(
                                  //               color: getTheme(context).editorBackgroundColor!,
                                  //               blurRadius: 3,
                                  //             ),
                                  //           ],
                                  //         ),
                                  //      ),
                                  //    ),
                                ],
                              ),
                              const SizedBox(width: 15),
                              if (state == ImagePreviewState.loading || state == ImagePreviewState.notFound)
                                const Text("Select or drop image")
                              else if (state == ImagePreviewState.error)
                                const Text("Error loading image")
                              else if (state == ImagePreviewState.loaded)
                                Flexible(
                                  child: Text(basename(widget.imgPath), overflow: TextOverflow.ellipsis),
                                ),
                              const SizedBox(width: 5),
                            ],
                          );
                        }
                      ),
                    );
                  }
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    strokeWidth: 2,
                    color: getTheme(context).textColor!.withOpacity(0.25),
                    radius: const Radius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.file_download_outlined, size: 32),
                        const SizedBox(width: 15),
                        Align(
                          alignment: Alignment.center,
                          child: Text("Drop image file", style: Theme.of(context).textTheme.bodyLarge)
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void pickSrcFile() async {
    var paths = await FS.i.selectFiles(
      dialogTitle: "Pick image",
    );
    if (paths.isEmpty)
      return;
    widget.onDrop(paths.first);
  }
}
