
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/events/statusInfo.dart';
import 'messageLog.dart';

class Statusbar extends StatelessWidget {
  const Statusbar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Material(
        color: getTheme(context).sidebarBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Container(),),
            MessageLog(),
            Container(
              width: 20,
              height: 20,
              padding: const EdgeInsets.all(6),
              child: ChangeNotifierBuilder(
                notifier: isLoadingStatus,
                builder: (context) => 
                  AnimatedOpacity(
                    opacity: isLoadingStatus.isLoading ? 0.5 : 0,
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
