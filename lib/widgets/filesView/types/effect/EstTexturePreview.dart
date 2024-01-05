
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/expandOnHover.dart';
import '../../../theme/customTheme.dart';

class EstTexturePreview extends ChangeNotifierWidget {
  final NumberProp textureFileId;
  final NumberProp textureFileTextureIndex;
  final double size;

  EstTexturePreview({
    required this.textureFileId,
    required this.textureFileTextureIndex,
    this.size = 20,
  })
    : super(
      key: Key(textureFileId.uuid + textureFileTextureIndex.uuid),
      notifiers: [textureFileId, textureFileTextureIndex]
    );

  @override
  State<EstTexturePreview> createState() => _EstTexturePreviewState();
}

class _EstTexturePreviewState extends ChangeNotifierState<EstTexturePreview> {
  @override
  Widget build(BuildContext context) {
    var texFileId = widget.textureFileId.value;
    var texFileIndex = widget.textureFileTextureIndex.value;
    // if (texFileId == 0 && texFileIndex == 0)
    //   return SizedBox(width: widget.size, height: widget.size);
    var imgName = "${texFileId.toString().padLeft(3, "0")}.wtp_$texFileIndex.png";
    var imgPath = "assets/effect/texture_thumbnails/$imgName";
    return ExpandOnHover(
      size: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image(
          image: AssetImage(imgPath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _makeNotFoundWidget(context),
        ),
      ),
    );
  }

  Widget _makeNotFoundWidget(BuildContext context) {
    return Text(
      "?",
      style: TextStyle(
        fontSize: widget.size,
        fontWeight: FontWeight.bold,
        color: getTheme(context).textColor!.withOpacity(0.333),
      ),
    );
  }
}
