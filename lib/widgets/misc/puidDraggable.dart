
import 'package:flutter/material.dart';

import '../../fileTypeUtils/yax/hashToStringMap.dart';
import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class PuidDraggable extends StatelessWidget {
  final String code;
  final int id;
  final String? name;
  final PuidRefData puid;
  final void Function()? onDragStarted;
  final void Function()? onDragEnd;
  final Widget child;

  PuidDraggable({
    super.key,
    required this.code,
    required this.id,
    String? name,
    this.onDragStarted,
    this.onDragEnd,
    required this.child
  }) :
    name = name ?? hashToStringMap[id],
    puid = PuidRefData(code, crc32(code), id);

  @override
  Widget build(BuildContext context) {
    return Draggable<PuidRefData>(
      data: puid,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      feedback: Material(
        color: getTheme(context).formElementBgColor!.withOpacity(0.75),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 300,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.link, size: 25,),
              const SizedBox(width: 8,),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 25),
                      child: Text(
                        code,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4,),
                    Text(
                      name ?? "0x${id.toRadixString(16)}",
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}
