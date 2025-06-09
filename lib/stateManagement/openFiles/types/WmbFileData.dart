

import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:universal_ffi/ffi.dart' as ffi;
import 'package:universal_ffi/ffi_utils.dart';

import '../../../fileTypeUtils/dat/datExtractor.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../../../fileSystem/FileSystem.dart';
import '../../../../ffi/FfiHelper.dart';
import 'wmb/TextureOutput.dart';
import 'wmb/WmbMeshState.dart';

class WmbFileData extends OpenFileData {
  String? wmbName;
  Uint8List? wmbData;
  Uint8List? wtaWtbData;
  Uint8List? wtpData;
  final textureManager = WmbTextureManager();

  WmbFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.wmb, icon: Icons.view_in_ar);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var parent = dirname(path);
    var datDir = "${withoutExtension(parent)}.dat";
    var dttDir = "${withoutExtension(parent)}.dtt";
    if (!await FS.i.existsDirectory(datDir)) {
      await _tryExtract(datDir);
    }
    if (!await FS.i.existsDirectory(dttDir)) {
      await _tryExtract(dttDir);
    }

    wmbName = basenameWithoutExtension(path);
    wmbData = await FS.i.read(path);

    var texBase = wmbName!;
    if (path.endsWith(".scr"))
      texBase += "scr";
    var wtaPath = join(datDir, "$texBase.wta");
    var wtbPath = join(dttDir, "$texBase.wtb");
    var wtpPath = join(dttDir, "$texBase.wtp");
    var [wtaExists, wtbExists, wtpExists] = await Future.wait([
      FS.i.existsFile(wtaPath),
      FS.i.existsFile(wtbPath),
      FS.i.existsFile(wtpPath),
    ]);
    if (wtaExists && wtpExists) {
      var [wtaWtb, wtp] = await Future.wait([
        FS.i.read(wtaPath),
        FS.i.read(wtpPath),
      ]);
      wtaWtbData = wtaWtb;
      wtpData = wtp;
    }
    else if (wtbExists) {
      var wtb = await FS.i.read(wtbPath);
      wtaWtbData = wtb;
    }

    loadingState.value = LoadingState.loaded;
    setHasUnsavedChanges(false);
    onUndoableEvent(immediate: true);
  }

  Future<void> _tryExtract(String datDir) async {
    var baseName = basename(datDir);
    var datOrigDir = dirname(dirname(datDir));
    var origDat = join(datOrigDir, baseName);
    if (await FS.i.existsFile(origDat)) {
      if (await FS.i.getSize(origDat) > 0) {
        try {
          await extractDatFiles(origDat);
        } on Exception {
          showToast("Failed to extract $baseName");
        }
      }
    }
  }
  
  @override
  void dispose() {
    super.dispose();
    textureManager.dispose();
  }

  @override
  Future<void> save() async {
    setHasUnsavedChanges(false);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WmbFileData(name.value, path, secondaryName: secondaryName.value);
    snapshot.overrideUuid(uuid);
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    // TODO: implement restoreWith
  }
}


class WmbTextureManager {
  static final textureOutputMode = isWeb ? TextureOutputMode.imageStream : TextureOutputMode.textureId;
  static ffi.Pointer<ffi.Void> _context = ffi.nullptr;
  final textureOutput = TextureOutput.create();
  bool isInitialized = false;
  bool isInitializing = false;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _hasRenderQueued = false;
  ffi.Pointer<ffi.Void> _rendererState = ffi.nullptr;
  Size previousSize = Size.zero;
  late int _bufferSize;
  ffi.Pointer<ffi.Uint8> _buffer = ffi.nullptr;
  final List<ffi.Pointer<ffi.Uint8>> _allocated = [];
  late final WmbMeshState rootMeshState;
  Color backgroundColor = Color.fromRGBO(38, 38, 38, 1.0);

  WmbTextureManager() {
    rootMeshState = WmbMeshState("Root", -1, true, setModelVisible);
  }

  Future<void> init(
    String wmbName,
    Uint8List wmbData,
    Uint8List? wtaWtbData,
    Uint8List? wtpData,
    Size screenSize,
    Size widgetSize,
  ) async {
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
      _context = _safeCallPtr(() => FfiHelper.i.rustyPlatinumUtils.rpu_new_context());
      if (_context == ffi.nullptr) {
        _hasError = true;
        throw Exception("Failed to create renderer context");
      }
    }

    var wmbNamePtr = wmbName.toNativeUtf8();
    var (wmbDataPtr, wmbDataLen) = _bufferFrom(wmbData);
    var (wtaWtbDataPtr, wtaWtbDataLen) = _bufferFrom(wtaWtbData);
    var (wtpDataPtr, wtpDataLen) = _bufferFrom(wtpData);
    _allocated.add(wmbNamePtr.cast<ffi.Uint8>());
    _allocated.add(wmbDataPtr);
    _allocated.add(wtaWtbDataPtr);
    _allocated.add(wtpDataPtr);
    var sceneData = _safeCallPtr(() => FfiHelper.i.rustyPlatinumUtils.rpu_load_wmb_from_bytes(
      wmbNamePtr.cast<ffi.Char>(),
      wmbDataPtr,
      wmbDataLen,
      wtaWtbDataPtr,
      wtaWtbDataLen,
      wtpDataPtr,
      wtpDataLen,
    ));
    if (sceneData == ffi.nullptr) {
      _hasError = true;
      throw Exception("Failed to load wmb file");
    }
    
    _rendererState = _safeCallPtr(() => FfiHelper.i.rustyPlatinumUtils.rpu_new_renderer(
      _context,
      widgetSize.width.toInt(),
      widgetSize.height.toInt(),
      sceneData,
    ));
    if (_rendererState == ffi.nullptr) {
      _hasError = true;
      throw Exception("Failed to create renderer");
    }

    await textureOutput.init();
    previousSize = widgetSize;
    _bufferSize = screenSize.width.toInt() * screenSize.height.toInt() * 4;
    _buffer = calloc<ffi.Uint8>(_bufferSize);

    var initialModelStatesStr = (_safeCallPtr(() => FfiHelper.i.rustyPlatinumUtils.rpu_get_model_states(_rendererState)).cast<Utf8>()).toDartString();
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
    unawaited(textureOutput.dispose());
    if (_rendererState != ffi.nullptr) {
      FfiHelper.i.rustyPlatinumUtils.rpu_drop_renderer(_rendererState);
      _rendererState = ffi.nullptr;
    }
    for (var ptr in [_buffer, ..._allocated]) {
      if (ptr != ffi.nullptr)
        calloc.free(ptr);
    }
    _buffer = ffi.nullptr;
  }

  bool get isReady {
    return isInitialized && !_isDisposed;
  }

  bool get hasError {
    return _hasError;
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
    // var sw = Stopwatch()..start();
    var texBufferSize = _safeCallInt(() => FfiHelper.i.rustyPlatinumUtils.rpu_render(
      _rendererState,
      _buffer,
      _bufferSize,
      widgetSize.width.toInt(),
      widgetSize.height.toInt(),
      backgroundColor.red / 255.0,
      backgroundColor.green / 255.0,
      backgroundColor.blue / 255.0,
      backgroundColor.opacity,
    ));
    // print("Render time: ${sw.elapsedMilliseconds}ms");
    if (texBufferSize != -1) {
      textureOutput.onRgba(_buffer, texBufferSize, previousSize.width.toInt(), previousSize.height.toInt());
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
    if (!textureOutput.isReady) {
      _hasError = true;
      throw Exception("WmbTextureManager textureOutput is not ready");
    }
    if (_rendererState == ffi.nullptr) {
      _hasError = true;
      throw Exception("WmbTextureManager rendererState is null");
    }
  }
}

ffi.Pointer<T> _safeCallPtr<T extends ffi.NativeType>(ffi.Pointer<T> Function() func) {
  try {
    return func();
  } catch (e, st) {
    print("Error in WmbTextureManager: $e\n$st");
    return ffi.nullptr;
  }
}

int _safeCallInt(int Function() func) {
  try {
    return func();
  } catch (e, st) {
    print("Error in WmbTextureManager: $e\n$st");
    return -1;
  }
}

(ffi.Pointer<ffi.Uint8>, int) _bufferFrom(Uint8List? data) {
  if (data == null) {
    return (ffi.nullptr, 0);
  }
  var ptr = calloc<ffi.Uint8>(data.length);
  ptr.asTypedList(data.length).setAll(0, data);
  return (ptr, data.length);
}
