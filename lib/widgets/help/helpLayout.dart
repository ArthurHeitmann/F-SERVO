
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../utils/utils.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/markdownWidgetCustom.dart';
import 'helpData.dart';

class HelpLayout extends StatefulWidget {
  const HelpLayout({super.key});

  @override
  State<HelpLayout> createState() => _HelpLayoutState();
}

class _HelpLayoutState extends State<HelpLayout> {
  List<HelpPage> helpData = [];
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    loadHelpData().then((value) => setState(() => helpData = value));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 150,
          child: SmoothScrollBuilder(
            builder: (context, controller, physics) {
              return ListView(
                controller: controller,
                physics: physics,
                children: [
                  for (var i = 0; i < helpData.length; i++)
                    ListTile(
                      minTileHeight: 30,
                      title: Text(helpData[i].title),
                      onTap: () => setState(() => currentPage = i),
                      selected: i == currentPage,
                    ),
                ],
              );
            }
          ),
        ),
        Container(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: helpData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : MarkdownWidgetCustom(
                  data: helpData[currentPage].content,
                  selectable: false,
                  config: MarkdownConfig(
                    configs: [
                      CodeConfig.darkConfig,
                      ImgConfig(
                        builder: (url, attributes) {
                          var img = url.startsWith("http")
                            ? Image.network(url)
                            : Image.asset(url);
                          return GestureDetector(
                            onTap: () => _BigOverlayImage.show(context: context, child: img),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: img,
                            ),
                          );
                        },
                      )
                    ]
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

class _BigOverlayImage extends StatelessWidget {
  static const edgePadding = EdgeInsets.all(50);
  final OverlayEntry overlayEntry;
  final Widget child;

  const _BigOverlayImage._({required this.overlayEntry, required this.child});

  factory _BigOverlayImage.show({required BuildContext context, required Widget child}) {
    _BigOverlayImage? bigOverlayImage;
    var overlayEntry = OverlayEntry(builder: (context) => bigOverlayImage!);
    bigOverlayImage = _BigOverlayImage._(overlayEntry: overlayEntry, child: child);
    Overlay.of(context).insert(overlayEntry);
    return bigOverlayImage;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: titleBarHeight),
      child: GestureDetector(
        onTap: () => overlayEntry.remove(),
        child: Material(
          color: Colors.black.withOpacity(0.5),
          child: Padding(
            padding: edgePadding,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
