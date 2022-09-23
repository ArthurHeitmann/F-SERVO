

import 'package:flutter/material.dart';

import '../../customTheme.dart';

class Statusbar extends StatelessWidget {
  const Statusbar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).sidebarBackgroundColor,
        ),
        child: Row(
          children: [
            Text("Statusbar"),
          ],
        ),
      ),
    );
  }
}
