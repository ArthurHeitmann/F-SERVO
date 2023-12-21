
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/expandOnHover.dart';
import '../../../theme/customTheme.dart';

class EstModelPreview extends ChangeNotifierWidget {
  final HexProp modelId;
  final double size;

  EstModelPreview({
    required this.modelId,
    this.size = 20,
  })
    : super(
      key: Key("Model_${modelId.uuid}"),
      notifier: modelId
    );

  @override
  State<EstModelPreview> createState() => _EstModelPreviewState();
}

class _EstModelPreviewState extends ChangeNotifierState<EstModelPreview> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox();
    var modelId = widget.modelId.value;
    if (modelId == 0)
      return SizedBox(width: widget.size, height: widget.size);
    var imgName = "${modelId.toRadixString(16).padLeft(4, "0")}.png";
    var imgPath = "assets/effect/model_thumbnails/$imgName";
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
