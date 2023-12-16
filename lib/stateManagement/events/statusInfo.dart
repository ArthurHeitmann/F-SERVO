
import 'package:flutter/material.dart';

import '../listNotifier.dart';

class IsLoadingStatus extends ChangeNotifier {
  int _loadingActivities = 0;

  bool get isLoading => _loadingActivities > 0;

  void pushIsLoading() {
    _loadingActivities++;
    if (_loadingActivities == 1)
      notifyListeners();
  }

  void popIsLoading() {
    if (_loadingActivities == 0)
      throw Exception("No active loading activities!");
    _loadingActivities--;
    if (_loadingActivities == 0)
      notifyListeners();
  }
}

final isLoadingStatus = IsLoadingStatus();

final ValueListNotifier<String> messageLog = ValueListNotifier<String>([], fileId: null)
  ..addListener(() => print("messageLog: ${messageLog.last}"));
