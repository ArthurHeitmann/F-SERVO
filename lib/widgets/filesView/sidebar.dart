
import 'package:flutter/material.dart';

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

  const Sidebar({ super.key, required this.entries, this.switcherPosition = SidebarSwitcherPosition.left });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.switcherPosition == SidebarSwitcherPosition.left) ...[
          _buildSwitcher(),
          const VerticalDivider(width: 1,),
        ],
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: widget.entries.map((e) => e.child).toList(),
          ),
        ),
        if (widget.switcherPosition == SidebarSwitcherPosition.right) ...[
          const VerticalDivider(width: 1,),
          _buildSwitcher(),
        ],
      ],
    );
  }

  Widget _buildSwitcher() {
    return SizedBox(
      width: 25,
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
      onPressed: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: RotatedBox(
          quarterTurns: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (entry.icon != null)
                Icon(entry.icon, size: 14,),
              const SizedBox(width: 5),
              Text(entry.name),
            ],
          ),
        ),
      ),
    );
  }
}
