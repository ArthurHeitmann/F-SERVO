
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../fileSystem/FileSystem.dart';
import '../../fileTypeUtils/textures/ddsConverter.dart';
import '../../stateManagement/Property.dart';
import '../misc/dropTargetBuilder.dart';
import '../misc/imagePreviewBuilder.dart';
import '../misc/onHoverBuilder.dart';
import '../theme/customTheme.dart';

class DdsTool extends StatefulWidget {
  const DdsTool({super.key});

  @override
  State<DdsTool> createState() => _DdsToolState();
}

enum _TextureFormat {
  png("PNG", "png"),
  dds("DDS", "dds");
  
  final String name;
  final String ext;

  const _TextureFormat(this.name, this.ext);
}
enum _DdsCompression {
  dxt1("DXT1 (BC1)", "dxt1"),
  dxt5("DXT5 (BC3)", "dxt5");
  
  final String name;
  final String ext;

  const _DdsCompression(this.name, this.ext);
}

class _DdsToolState extends State<DdsTool> {
  String srcPath = "";
  var format = _TextureFormat.dds;
  var compression = _DdsCompression.dxt1;
  var mipmaps = BoolProp(false, fileId: null);

  final imageKey = const PageStorageKey("imgPreview");

  void pickSrcFile() async {
    var paths = await FS.i.selectFiles(
      dialogTitle: "Pick source image",
    );
    if (paths.isEmpty)
      return;
    setState(() => srcPath = paths.first);
  }

  void convert() async {
    var savePath = await FS.i.selectSaveFile(
      dialogTitle: "Save image as ${format.name}",
      allowedExtensions: [format.ext],
      fileName: "${basenameWithoutExtension(srcPath)}.${format.ext}",
    );
    if (savePath == null)
      return;
    switch (format) {
      case _TextureFormat.png:
        await texToPng(srcPath, pngPath: savePath);
        break;
      case _TextureFormat.dds:
        await texToDds(srcPath, savePath, compression: compression.ext, mipmaps: mipmaps.value ? 10 : 0);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeSrcPicker(context),
        makeOptions(context),
        makeSaveButton(context),
      ],
    );
  }

  Widget makeSrcPicker(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(height: 50),
      child: DropTargetBuilder(
        onDrop: (paths) => setState(() => srcPath = paths.first),
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
                        path: srcPath,
                        maxHeight: 50,
                        builder: (context, data, state) {
                          return Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 5),
                              if (state == ImagePreviewState.loading || state == ImagePreviewState.notFound)
                                const Icon(Icons.file_download_outlined, size: 24)
                              else if (state == ImagePreviewState.error)
                                const Icon(Icons.error_outline, size: 24)
                              else if (state == ImagePreviewState.loaded)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 44, maxWidth: 100),
                                  child: Image.memory(data!)
                                ),
                              const SizedBox(width: 15),
                              if (state == ImagePreviewState.loading || state == ImagePreviewState.notFound)
                                const Text("Select or drop image")
                              else if (state == ImagePreviewState.error)
                                const Text("Error loading image")
                              else if (state == ImagePreviewState.loaded)
                                Text(basename(srcPath)),
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
                  strokeWidth: 2,
                  color: getTheme(context).textColor!.withOpacity(0.25),
                  radius: const Radius.circular(12),
                  borderType: BorderType.RRect,
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

  Widget makeOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeMultiOption(context, "Format", format, _TextureFormat.values.map((e) => (name: e.name, value: e)), (v) => format = v),
        if (format == _TextureFormat.dds) ...[
          makeMultiOption(context, "Compression", compression, _DdsCompression.values.map((e) => (name: e.name, value: e)), (v) => compression = v),
          GestureDetector(
            onTap: () => setState(() => mipmaps.value = !mipmaps.value),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Text("Mipmaps: "),
                Checkbox(
                  value: mipmaps.value,
                  onChanged: (v) => setState(() => mipmaps.value = v!),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget makeMultiOption<T>(BuildContext context, String title, T value, Iterable<({String name, T value})> options, void Function(T) onChanged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<T>(
          initialValue: value,
          onSelected: (v) => setState(() => onChanged(v)),
          itemBuilder: (context) => options.map((e) => PopupMenuItem(
            value: e.value,
            height: 20,
            padding: const EdgeInsets.only(right: 33),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(e.name)
            ),
          )).toList(),
          position: PopupMenuPosition.under,
          constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
          popUpAnimationStyle: AnimationStyle(duration: Duration.zero),
          tooltip: "",
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Text(title),
                const Spacer(),
                Text(
                  options.firstWhere((e) => e.value == value).name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget makeSaveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: ElevatedButton(
        onPressed: srcPath.isEmpty ? null : convert,
        child: const Text("Save"),
      ),
    );
  }
}
