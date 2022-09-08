
import 'package:flutter/src/widgets/container.dart';
import 'package:nier_scripts_editor/stateManagement/FileHierarchy.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;

  HierarchyEntryWidget(this.entry {super.key}) : super(notifier: entry);

  @override
  State<HierarchyEntryWidget> createState() => _HierarchyEntryState();
}

class _HierarchyEntryState extends ChangeNotifierState<HierarchyEntryWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestrueDetector(
          onDoubleTap: widget.entry.isOpenable ? widget.entry.onOpen : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center
            children: [
              if (widget.entry.isCollapsible)
                IconButton(
                  icon: widget.entry.isCollapsed ? Icons.lol : Icons.lol2,
                  onPressed: () => widget.entry.isCollapsed = !widget.entry.isCollapsed
                ),
              if (widget.entry.icon)
                Icon(icon: widget.entry.icon!),
              Text(widget.entry.name)
            ]
          ),
        ),
        for (var child in widget.entry)
          Padding(
            padding: EdgeInserts.only(left: 10),
            child: HierarchyEntryWidget(child)
          )
      ]
	  );
  }
}
