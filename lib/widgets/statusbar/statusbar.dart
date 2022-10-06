

import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/statusInfo.dart';

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
            Expanded(child: Container(),),
            Container(
              width: 25,
              height: 25,
              padding: const EdgeInsets.all(6),
              child: ChangeNotifierBuilder(
                notifier: isLoadingStatus,
                builder: (context) => 
                  AnimatedOpacity(
                    opacity: isLoadingStatus.isLoading ? 0.35 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: CircularProgressIndicator(strokeWidth: 2, color: getTheme(context).textColor,),
                  ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
