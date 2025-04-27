
import 'dart:ui';

import '../widgets/filesView/types/wmb/WmbMeshState.dart';

class FfiHelper {
  static late final FfiHelper i;

  FfiHelper(String assetsDir);
}

class WmbTextureManager {
  bool isInitialized = true;
  bool isInitializing = false;
  Size previousSize = Size.zero;
  Color backgroundColor = Color(0xFF262626);
  final rootMeshState = WmbMeshState("Root", -1, true, (_, __) {});

  WmbTextureManager();

  Future<void> init(String wmbPath, Size screenSize, Size widgetSize) async {}

  void dispose() {}

  bool get isReady {
    return false;
  }

  bool get hasError {
    return true;
  }

  int get textureId {
    throw Exception("Texture ID not available in stub");
  }

  void setSize(Size screenSize, Size widgetSize) {}

  void addCameraRotation(double horizontal, double vertical) {}

  void addCameraOffset(double horizontal, double vertical) {}

  void addCameraDistance(double distance) {}

  void autoSetTarget() {}

  void setModelVisible(int id, bool isVisible) {}

  void safetyCheck() {}
}
