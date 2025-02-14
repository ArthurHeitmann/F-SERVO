
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:texture_rgba_renderer/texture_rgba_renderer.dart';
import 'package:texture_rgba_renderer/texture_rgba_ffi.dart';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import '../../../../ffi/FfiHelper.dart';

class WmbMeshState {
  final String name;
  final int id;
  bool _isVisible;
  final List<WmbMeshState> children = [];
  final void Function(int, bool) _setModelVisible;

  WmbMeshState(this.name, this.id, this._isVisible, this._setModelVisible);

  void addChild(List<String> path, int id, bool isVisible) {
    if (path.length == 1) {
      children.add(WmbMeshState(path[0], id, isVisible, _setModelVisible));
      return;
    }
    var child = children.where((c) => c.name == path[0]).firstOrNull;
    if (child == null) {
      child = WmbMeshState(path[0], -1, isVisible, _setModelVisible);
      children.add(child);
    }
    child.addChild(path.sublist(1), id, isVisible);
  }

  set isVisible(bool? value) {
    _isVisible = value!;
    if (children.isEmpty)
      _setModelVisible(id, value);
    for (var child in children)
      child.isVisible = value;
  }

  bool? get isVisible {
    if (children.isEmpty) {
      return _isVisible;
    }
    var visibleChildren = children.where((c) => c.isVisible == true);
    var invisibleChildren = children.where((c) => c.isVisible == false);
    if (visibleChildren.isNotEmpty && invisibleChildren.isNotEmpty) {
      return null;
    }
    return visibleChildren.isNotEmpty;
  }
}

class WmbTextureManager {
  static final TextureRgbaRenderer _rgbaRenderer = TextureRgbaRenderer();
  static int _nextId = 0;
  static ffi.Pointer<ffi.Void> _context = ffi.nullptr;
  bool isInitialized = false;
  bool isInitializing = false;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _hasRenderQueued = false;
  final int _textureKey = _nextId++;
  int? _textureId;
  ffi.Pointer<ffi.Void> _texturePointer = ffi.nullptr;
  ffi.Pointer<ffi.Void> _rendererState = ffi.nullptr;
  Size previousSize = Size.zero;
  late int _bufferSize;
  late ffi.Pointer<ffi.Uint8> _buffer;
  late final WmbMeshState rootMeshState;
  Color backgroundColor = Color.fromRGBO(38, 38, 38, 1.0);

  WmbTextureManager() {
    rootMeshState = WmbMeshState("Root", -1, true, setModelVisible);
  }

  Future<void> init(String wmbPath, Size screenSize, Size widgetSize) async {
    if (isInitialized) {
      _hasError = true;
      throw Exception("WmbTextureManager is already initialized");
    }
    if (_isDisposed) {
      _hasError = true;
      throw Exception("WmbTextureManager is disposed");
    }
    if (isInitializing) {
      _hasError = true;
      throw Exception("WmbTextureManager is already initializing");
    }
    isInitializing = true;
    if (_context == ffi.nullptr) {
      _context = FfiHelper.i.rustyPlatinumUtils.rpu_new_context();
      if (_context == ffi.nullptr) {
        _hasError = true;
        throw Exception("Failed to create renderer context");
      }
    }
    var wmbPathPointer = await Isolate.run(() {
      return wmbPath.toNativeUtf8().cast<ffi.Char>();
    });
    var sceneData = FfiHelper.i.rustyPlatinumUtils.rpu_load_wmb(wmbPathPointer);
    calloc.free(wmbPathPointer);
    if (sceneData == ffi.nullptr) {
      _hasError = true;
      throw Exception("Failed to load wmb file");
    }
    _rendererState = FfiHelper.i.rustyPlatinumUtils.rpu_new_renderer(
      _context,
      widgetSize.width.toInt(),
      widgetSize.height.toInt(),
      sceneData,
    );
    if (_rendererState == ffi.nullptr) {
      _hasError = true;
      throw Exception("Failed to create renderer");
    }
    _textureId = await _rgbaRenderer.createTexture(_textureKey);
    _texturePointer = ffi.Pointer.fromAddress(await _rgbaRenderer.getTexturePtr(_textureKey));
    previousSize = widgetSize;
    _bufferSize = screenSize.width.toInt() * screenSize.height.toInt() * 4;
    _buffer = calloc<ffi.Uint8>(_bufferSize);

    var initialModelStatesStr = (FfiHelper.i.rustyPlatinumUtils.rpu_get_model_states(_rendererState) as ffi.Pointer<Utf8>).toDartString();
    for (var line in initialModelStatesStr.split("\n")) {
      line = line.trim();
      if (line.isEmpty) {
        continue;
      }
      var parts = line.split(",");
      var id = int.parse(parts[0]);
      var name = parts[1];
      var isVisible = parts[2] == "true";
      var path = name.split("/");
      rootMeshState.addChild(path, id, isVisible);
    }

    isInitialized = true;
    isInitializing = false;
    _render(widgetSize);
  }

  void dispose() {
    if (!isInitialized) {
      return;
    }
    if (_isDisposed) {
      throw Exception("WmbTextureManager is already disposed");
    }
    _isDisposed = true;
    _rgbaRenderer.closeTexture(_textureKey);
    FfiHelper.i.rustyPlatinumUtils.rpu_drop_renderer(_rendererState);
    _rendererState = ffi.nullptr;
    calloc.free(_buffer);
    _buffer = ffi.nullptr;
  }

  bool get isReady {
    return isInitialized && !_isDisposed;
  }

  bool get hasError {
    return _hasError;
  }

  int get textureId {
    safetyCheck();
    return _textureId!;
  }

  void setSize(Size screenSize, Size widgetSize) {
    safetyCheck();
    if (screenSize.width.toInt() * screenSize.height.toInt() * 4 > _bufferSize) {
      _bufferSize = screenSize.width.toInt() * screenSize.height.toInt() * 4;
      calloc.free(_buffer);
      _buffer = calloc<ffi.Uint8>(_bufferSize);
    }
    if (previousSize != widgetSize) {
      previousSize = widgetSize;
      _render(widgetSize);
    }
    else if (_hasRenderQueued) {
      _render(widgetSize);
      _hasRenderQueued = false;
    }
  }

  void _render(Size widgetSize) {
    safetyCheck();
    var texBufferSize = FfiHelper.i.rustyPlatinumUtils.rpu_render(
      _rendererState,
      _buffer,
      _bufferSize,
      widgetSize.width.toInt(),
      widgetSize.height.toInt(),
      backgroundColor.red / 255.0,
      backgroundColor.green / 255.0,
      backgroundColor.blue / 255.0,
      backgroundColor.opacity,
    );
    if (texBufferSize != -1) {
      TextureRgbaRendererNative.instance.onRgba(_texturePointer, _buffer, texBufferSize, previousSize.width.toInt(), previousSize.height.toInt(), 0);
    }
  }

  void addCameraRotation(double horizontal, double vertical) {
    safetyCheck();
    const factor = -0.01;
    FfiHelper.i.rustyPlatinumUtils.rpu_add_camera_rotation(_rendererState, vertical * factor, horizontal * factor);
    _hasRenderQueued = true;
  }

  void addCameraOffset(double horizontal, double vertical) {
    safetyCheck();
    const factor = 0.001;
    FfiHelper.i.rustyPlatinumUtils.rpu_add_camera_offset(_rendererState, vertical*factor, horizontal*factor);
    _hasRenderQueued = true;
  }

  void addCameraDistance(double distance) {
    safetyCheck();
    FfiHelper.i.rustyPlatinumUtils.rpu_zoom_camera_by(_rendererState, -distance * 0.01);
    _hasRenderQueued = true;
  }

  void autoSetTarget() {
    safetyCheck();
    FfiHelper.i.rustyPlatinumUtils.rpu_auto_set_target(_rendererState);
    _hasRenderQueued = true;
  }

  void setModelVisible(int id, bool isVisible) {
    safetyCheck();
    FfiHelper.i.rustyPlatinumUtils.rpu_set_model_visibility(_rendererState, id, isVisible);
    _hasRenderQueued = true;
  }

  void safetyCheck() {
    if (!isInitialized) {
      _hasError = true;
      throw Exception("WmbTextureManager is not initialized");
    }
    if (_isDisposed) {
      _hasError = true;
      throw Exception("WmbTextureManager is disposed");
    }
    if (_textureId == null) {
      _hasError = true;
      throw Exception("WmbTextureManager textureId is null");
    }
    if (_rendererState == ffi.nullptr) {
      _hasError = true;
      throw Exception("WmbTextureManager rendererState is null");
    }
  }
}
