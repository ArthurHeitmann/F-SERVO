

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../../stateManagement/openFiles/types/WmbFileData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../propEditors/UnderlinePropTextField.dart';
import '../../../propEditors/propEditorFactory.dart';
import '../../../propEditors/propTextField.dart';
import '../../../theme/customTheme.dart';
import '../../../../stateManagement/openFiles/types/wmb/TextureOutput.dart';
import '../../../../stateManagement/openFiles/types/wmb/WmbMeshState.dart';

class WmbRenderer extends StatefulWidget {
  final WmbFileData file;

  const WmbRenderer({super.key, required this.file});

  @override
  State<WmbRenderer> createState() => _WmbRendererState();
}

class _WmbRendererState extends State<WmbRenderer> {
  final searchString = StringProp("", fileId: null);
  WmbTextureManager get textureManager => widget.file.textureManager;

  @override
  void initState() {
    super.initState();
    if (widget.file.loadingState.value != LoadingState.loaded)
      widget.file.load().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var screenSize = MediaQuery.of(context).size;
        var maxSize = constraints.biggest;
        if (textureManager.isReady) {
          if (textureManager.isInitialized) {
            textureManager.setSize(screenSize, maxSize);
          }
        } else if (!textureManager.isInitializing && widget.file.loadingState.value == LoadingState.loaded) {
          textureManager.init(widget.file.wmbName!, widget.file.wmbData!, widget.file.wtaWtbData, widget.file.wtpData, screenSize, maxSize)
            .whenComplete(() => setState(() {}));
        }
        if (!textureManager.isReady) {
          if (textureManager.hasError) {
            return Center(
              child: Text("Failed to initialize renderer"),
            );
          }
          return Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  textureManager.addCameraDistance(event.scrollDelta.dy);
                  setState(() {});
                }
              },
              onPointerDown: (event) {
                if (event.buttons == kMiddleMouseButton) {
                  textureManager.autoSetTarget();
                }
              },
              onPointerMove: (event) {
                if (event.buttons == kPrimaryMouseButton || event.buttons == kMiddleMouseButton) {
                  textureManager.addCameraRotation(event.delta.dx, event.delta.dy);
                  setState(() {});
                }
                else if (event.buttons == kSecondaryMouseButton) {
                  textureManager.addCameraOffset(event.delta.dy, -event.delta.dx);
                  setState(() {});
                }
              },
              child: _makeTextureRenderer(textureManager.textureOutput),
            ),
            _makeOverlay(context, constraints),
          ],
        );
      },
    );
  }

  _makeTextureRenderer(TextureOutput textureOutput) {
    if (textureOutput is TextureOutputTexture) {
      return Texture(textureId: textureOutput.textureId);
    } else if (textureOutput is TextureOutputImageStream) {
      return _ImageStreamRenderer(imageStream: textureOutput.stream);
    } else {
      return Text("Unknown texture output type: ${textureOutput.runtimeType}");
    }
  }

  Widget _makeOverlay(BuildContext context, BoxConstraints constraints) {
    return Positioned(
      top: 40,
      left: 20,
      width: 200,
      child: Container(
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(maxHeight: constraints.maxHeight - 80),
        color: getTheme(context).editorBackgroundColor!.withOpacity(0.5),
        child: SingleChildScrollView(
          child: ChangeNotifierBuilder(
            notifier: searchString,
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  makePropEditor<UnderlinePropTextField>(searchString, PropTFOptions(
                    constraints: BoxConstraints.tightFor(width: 180, height: 20),
                    hintText: "Search",
                  )),
                  for (var meshStates in textureManager.rootMeshState.children)
                    _makeMeshStateWidget(context, meshStates, 0),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _makeMeshStateWidget(BuildContext context, WmbMeshState meshState, int indent) {
    void onChanged(value) {
      value ??= false;
      meshState.isVisible = value;
      setState(() {});
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (searchString.value.isEmpty || meshState.name.toLowerCase().contains(searchString.value.toLowerCase()))
          SizedBox(
            height: 20,
            child: Row(
              children: [
                SizedBox(width: indent * 10),
                Checkbox(
                  value: meshState.isVisible,
                  tristate: meshState.children.isNotEmpty,
                  activeColor: Colors.transparent,
                  onChanged: onChanged,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(!(meshState.isVisible ?? false)),
                    child: Text(
                      meshState.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!meshState.children.every((c) => c.children.isEmpty))
          for (var child in meshState.children)
            _makeMeshStateWidget(context, child, indent + 1),
      ],
    );
  }
}

class _ImageStreamRenderer extends StatefulWidget {
  final Stream<RawTexture> imageStream;

  const _ImageStreamRenderer({required this.imageStream});

  @override
  State<_ImageStreamRenderer> createState() => _ImageStreamRendererState();
}

class _ImageStreamRendererState extends State<_ImageStreamRenderer> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RawTexture>(
      stream: widget.imageStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return RawImage(
            image: snapshot.data!.image,
            width: snapshot.data!.width.toDouble(),
            height: snapshot.data!.height.toDouble(),
          );
        } else {
          return Center(child: Text("Loading..."));
        }
      },
    );
  }
}
