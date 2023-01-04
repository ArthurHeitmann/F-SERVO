
import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class SidebarEntryConfig {
  final String name;
  final IconData? icon;
  final Widget child;

  SidebarEntryConfig({
    required this.name,
    required this.child,
    this.icon
  });
}

enum SidebarSwitcherPosition { left, right }

class Sidebar extends StatefulWidget {
  final List<SidebarEntryConfig> entries;
  final SidebarSwitcherPosition switcherPosition;
  final double initialWidth;

  const Sidebar({ super.key, required this.entries, required this.initialWidth, this.switcherPosition = SidebarSwitcherPosition.left });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int _selectedIndex = 0;
  double _width = 0;
  bool _isExpanded = true;
  OverlayEntry? _draggableOverlayEntry;
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;

    waitForNextFrame().then((_) {
      _draggableOverlayEntry = OverlayEntry(
        builder: (context) => _ResizeHandle(
          layerLink: _layerLink,
          switcherPosition: widget.switcherPosition,
          onWidthChanged: (w) => _onDrag(context, w),
        )
      );
      Overlay.of(context)!.insert(_draggableOverlayEntry!);
    });
  }

  @override
  void dispose() {
    _draggableOverlayEntry?.remove();
    super.dispose();
  }

  void _onDrag(BuildContext overlayContext, double width) {
    _width += width;
    if (_width < 150)
      _isExpanded = false;
    else if (!_isExpanded)
      _isExpanded = true;
    // rebuild self and handle
    setState(() {});
    overlayContext.findRenderObject()!.markNeedsLayout();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: getTheme(context).sidebarBackgroundColor,
      child: ConstrainedBox(
        constraints: _isExpanded
          ? BoxConstraints(maxWidth: _width)
          : const BoxConstraints(),
        child: Row(
          children: [
            if (widget.switcherPosition == SidebarSwitcherPosition.left) ...[
              _buildSwitcher(),
              const VerticalDivider(width: 1,),
            ],
            if (_isExpanded)
              Expanded(
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: widget.entries.map((e) => e.child).toList(),
                  ),
                ),
              ),
            if (widget.switcherPosition == SidebarSwitcherPosition.right) ...[
              const VerticalDivider(width: 1,),
              _buildSwitcher(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcher() {
    return SizedBox(
      width: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 1,),
          for (var i = 0; i < widget.entries.length; i++)
            _buildSwitcherEntry(i),
        ],
      ),
    );
  }

  Widget _buildSwitcherEntry(int index) {
    var entry = widget.entries[index];
    return TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(EdgeInsets.zero),
        alignment: Alignment.center,
        backgroundColor: MaterialStateProperty.all(
          _selectedIndex == index
            ? getTheme(context).textColor!.withOpacity(0.1)
            : Colors.transparent,
        ),
        foregroundColor: MaterialStateProperty.all(
          _selectedIndex == index
            ? getTheme(context).textColor
            : getTheme(context).textColor!.withOpacity(0.5),
        ),
      ),
      onPressed: () => setState(() {
        if (_selectedIndex == index)
          _isExpanded = !_isExpanded;
        else
          _isExpanded = true;
        _selectedIndex = index;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: RotatedBox(
          quarterTurns: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (entry.icon != null)
                Icon(entry.icon, size: 13),
              const SizedBox(width: 5),
              Text(
                entry.name,
                textScaleFactor: 0.9,
                style: const TextStyle(letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final void Function(double) onWidthChanged;
  final SidebarSwitcherPosition switcherPosition;
  final LayerLink layerLink;

  const _ResizeHandle({ required this.onWidthChanged, required this.switcherPosition, required this.layerLink });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: switcherPosition == SidebarSwitcherPosition.left
            ? Alignment.topRight
            : Alignment.topLeft,
          followerAnchor: switcherPosition == SidebarSwitcherPosition.left
            ? Alignment.topRight
            : Alignment.topLeft,
          child: SizedBox(
            width: 5,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (switcherPosition == SidebarSwitcherPosition.left)
                    onWidthChanged(details.delta.dx);
                  else
                    onWidthChanged(-details.delta.dx);
                },
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
