
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'SmoothScrollBuilder.dart';

class MarkdownWidgetCustom extends MarkdownWidget {
  const MarkdownWidgetCustom({
    super.key,
    required super.data,
    super.tocController,
    super.physics,
    super.shrinkWrap = false,
    super.selectable = true,
    super.padding,
    super.config,
    super.markdownGenerator,
  });

  @override
  MarkdownWidgetState createState() => MarkdownWidgetStateCustom();
}

class MarkdownWidgetStateCustom extends MarkdownWidgetState {
  final List<Widget> _widgets = [];

  ///when we've got the data, we need update data without setState() to avoid the flicker of the view
  @override
  void updateState() {
    indexTreeSet.clear();
    markdownGenerator = widget.markdownGenerator ?? MarkdownGenerator();
    final result = markdownGenerator.buildWidgets(
      widget.data,
      // onTocList: (tocList) {
      //   _tocController?.setTocList(tocList);
      // },
      config: widget.config,
    );
    _widgets.addAll(result);
  }

  ///this method will be called when [updateState] or [dispose]
  @override
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
  }

  ///
  @override
  Widget buildMarkdownWidget() {
    return SmoothScrollBuilder(
      controller: controller,
      builder: (context, controller, physics) {
        final markdownWidget = NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            final ScrollDirection direction = notification.direction;
            isForward = direction == ScrollDirection.forward;
            return true;
          },
          child: ListView.builder(
            shrinkWrap: widget.shrinkWrap,
            physics: physics,
            controller: controller,
            itemBuilder: (ctx, index) => wrapByAutoScroll(index,
                wrapByVisibilityDetector(index, _widgets[index]), controller as AutoScrollController),
            itemCount: _widgets.length,
            padding: widget.padding,
          ),
        );
        return widget.selectable
            ? SelectionArea(child: markdownWidget)
            : markdownWidget;
      },
    );
  }
}
