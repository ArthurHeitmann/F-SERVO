
import 'package:flutter/material.dart';

import '../nestedNotifier.dart';

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

final messageLog = ValueNestedNotifier<String>([]);
