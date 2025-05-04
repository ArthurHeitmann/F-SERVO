
import 'dart:async';
import 'dart:ui' as ui;

import 'package:texture_rgba_renderer/texture_rgba_ffi.dart';
import 'package:texture_rgba_renderer/texture_rgba_renderer.dart';
import 'package:universal_ffi/ffi.dart';

import '../../../../utils/utils.dart';

enum TextureOutputMode {
  textureId,
  imageStream,
}

abstract class TextureOutput {
  Future<void> init();
  Future<void> dispose();
  Future<void> onRgba(Pointer<Uint8> buffer, int len, int width, int height);
  bool get isReady;

  static TextureOutput create() {
    if (isWeb) {
      return TextureOutputImageStream();
    } else {
      return TextureOutputTexture();
    }
  }
}

class TextureOutputTexture implements TextureOutput {
  static final _rgbaRenderer = TextureRgbaRenderer();
  static int _nextId = 0;
  final int _textureKey = _nextId++;
  int? _textureId;
  Pointer<Void> _texturePointer = nullptr;

  int get textureId => _textureId!;

  @override
  bool get isReady => _textureId != null && _texturePointer != nullptr;

  @override
  Future<void> init() async {
    _textureId = await _rgbaRenderer.createTexture(_textureKey);
    _texturePointer = Pointer.fromAddress(await _rgbaRenderer.getTexturePtr(_textureKey));
  }

  @override
  Future<void> dispose() async {
    await _rgbaRenderer.closeTexture(_textureKey);
  }

  @override
  Future<void> onRgba(Pointer<Uint8> buffer, int len, int width, int height) async {
    TextureRgbaRendererNative.instance.onRgba(_texturePointer, buffer, len, width, height, 0);
  }
}

class RawTexture {
  final int width;
  final int height;
  final ui.Image image;

  RawTexture(this.width, this.height, this.image);
}

class TextureOutputImageStream implements TextureOutput {
  final _streamController = StreamController<RawTexture>();
  Stream<RawTexture> get stream => _streamController.stream;
  int _frameId = 0;
  int _lastDecodedFrameId = 0;
  bool _isDecoding = false;
  ({Pointer<Uint8> buffer, int len, int width, int height})? _queuedFrame;

  @override
  bool get isReady => true; // Always ready for image stream

  @override
  Future<void> init() async {
    // No initialization needed for image stream
  }

  @override
  Future<void> dispose() async {
    await _streamController.close();
  }

  @override
  Future<void> onRgba(Pointer<Uint8> buffer, int len, int width, int height) async {
    if (_isDecoding) {
      _queuedFrame = (buffer: buffer, len: len, width: width, height: height);
      return;
    }
    _isDecoding = true;
    var completer = Completer<ui.Image>();
    var frameId = ++_frameId; 
    ui.decodeImageFromPixels(
      buffer.asTypedList(len),
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (frameId > _lastDecodedFrameId) {
          _lastDecodedFrameId = frameId;
          completer.complete(image);
        }
        else {
          print("Frame $frameId discarded, already decoded frame $_lastDecodedFrameId");
        }
      },
    );
    final image = await completer.future;
    _streamController.add(RawTexture(width, height, image));
    _isDecoding = false;

    if (_queuedFrame != null) {
      var queuedFrame = _queuedFrame!;
      _queuedFrame = null;
      unawaited(onRgba(queuedFrame.buffer, queuedFrame.len, queuedFrame.width, queuedFrame.height));
    }
  }
}
