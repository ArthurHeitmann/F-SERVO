
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mutex/mutex.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../fileTypeUtils/audio/riffParser.dart';
import '../fileTypeUtils/audio/wemToWavConverter.dart';
import 'events/statusInfo.dart';

class AudioResourcePreview {
  final int sampleRate;
  final int totalSamples;
  final Duration duration;
  final List<double>? previewSamples;
  final int previewSampleRate;

  AudioResourcePreview(this.sampleRate, this.totalSamples, this.duration, this.previewSamples, this.previewSampleRate);
}

class AudioResource {
  String wavPath;
  AudioResourcePreview? preview;
  final String? wemPath;
  int _refCount = 0;
  final bool _deleteOnDispose;

  AudioResource(this.wavPath, this.wemPath, this.preview, this._deleteOnDispose);

  Future<void> dispose() => audioResourcesManager._disposeAudioResource(this);

  AudioResource newRef() {
    _refCount++;
    return this;
  }
}

/// Through this class, you can get a reference to an audio file and have to dispose it when you're done with it.
class AudioResourcesManager {
  final Map<String, AudioResource> _resources = {};
  final Map<String, Mutex> _loadingMutexes = {};
  String? _tmpDir;

  /// Returns a reference to the audio file at the given path.
  /// If the file is already loaded, it will return the same reference.
  /// If the file is not loaded, it will load it.
  Future<AudioResource> getAudioResource(String path, { bool makeCopy = false }) async {
    if (!_loadingMutexes.containsKey(path))
      _loadingMutexes[path] = Mutex();
    await _loadingMutexes[path]!.acquire();

    if (_resources.containsKey(path)) {
      _resources[path]!._refCount++;
      _loadingMutexes[path]!.release();
      return _resources[path]!;
    }

    var wavPath = path;
    bool deleteOnDispose = false;
    if (path.endsWith(".wem")) {
      wavPath = await wemToWavTmp(path);
      deleteOnDispose = true;
    } else if (makeCopy) {
      wavPath = await _copyToTmp(path);
      deleteOnDispose = true;
    }

    AudioResourcePreview? preview;
    try {
      var riff = await RiffFile.fromFile(wavPath);
      Tuple2<List<double>, int>? previewData = await _getPreviewData(riff);
      int totalSamples = riff.data.samples.length ~/ riff.format.channels;
      preview = AudioResourcePreview(
        riff.format.samplesPerSec,
        totalSamples,
        Duration(microseconds: (totalSamples * 1000000 ~/ riff.format.samplesPerSec)),
        previewData?.item1,
        previewData?.item2 ?? 1
      );
    } catch (e, st) {
      messageLog.add("Error loading audio file: $path\n$e\n$st");
    }
    var resource = AudioResource(
      wavPath,
      path.endsWith(".wem") ? path : null,
      preview,
      deleteOnDispose
    );
    resource._refCount++;
    _resources[path] = resource;

    _loadingMutexes[path]!.release();

    return resource;
  }

  Future<String> _copyToTmp(String path) async {
    _tmpDir ??= (await Directory.systemTemp.createTemp("tmpWav")).path;
    var tmpPath = join(_tmpDir!, basename(path));
    await File(path).copy(tmpPath);
    return tmpPath;
  }

  Future<void> reloadAudioResource(AudioResource resource) async {
    if (resource.wemPath != null)
      resource.wavPath = await wemToWavTmp(resource.wemPath!);
    try {
      var riff = await RiffFile.fromFile(resource.wavPath);
      Tuple2<List<double>, int>? previewData = await _getPreviewData(riff);
      int totalSamples = riff.data.samples.length ~/ riff.format.channels;
      resource.preview = AudioResourcePreview(
        riff.format.samplesPerSec,
        totalSamples,
        Duration(microseconds: (totalSamples * 1000000 ~/ riff.format.samplesPerSec)),
        previewData?.item1,
        previewData?.item2 ?? 1,
      );
    } on Exception catch (e, st) {
      messageLog.add("Error reloading audio file: ${resource.wavPath}\n$e\n$st");
    }
  }

  Future<void> disposeAll() async {
    var allDeletableFiles = _resources.values
      .where((resource) => resource._deleteOnDispose)
      .map((resource) => resource.wavPath)
      .toList();

    await Future.wait(allDeletableFiles.map((path) async {
      if (await File(path).exists())
        await File(path).delete();
    }));

    if (_tmpDir != null && await Directory(_tmpDir!).exists())
      await Directory(_tmpDir!).delete(recursive: true);
  }

  /// Disposes the reference to the audio file at the given path.
  /// If the reference count reaches 0, the file will be unloaded.
  Future<void> _disposeAudioResource(AudioResource resource) async {
    resource._refCount--;
    if (resource._refCount <= 0) {
      _resources.removeWhere((key, value) => value == resource);
      if (resource._deleteOnDispose) {
        if (await File(resource.wavPath).exists())
          await File(resource.wavPath).delete();
        else
          print("Warning: Tried to delete file ${resource.wavPath} but it doesn't exist.");
      }
    }
  }

  Future<Tuple2<List<double>, int>?> _getPreviewData(RiffFile riff) async {
    if (riff.format.formatTag != 1 && riff.format.formatTag != 3)
      return null;
    const previewSampleRate = 200;
    List<num> rawSamples = riff.data.samples;
    var samplesCount = rawSamples.length;
    int bitsPerSample = riff.format.bitsPerSample;
    var scaleFactor = pow(2, bitsPerSample - 1);
    if (riff.format.formatTag == 3 && bitsPerSample == 32) {
      // convert int bytes to float
      var t1 = DateTime.now();
      var intList = Int32List.fromList(rawSamples as List<int>);
      rawSamples = Float32List.view(intList.buffer);
      scaleFactor = 1;
      var t2 = DateTime.now();
      print("Converted ${samplesCount ~/ 1000}k samples in ${t2.difference(t1).inMilliseconds}ms");
    }
    int previewSampleCount = samplesCount ~/ riff.format.blockAlign ~/ previewSampleRate;
    var wavSamples = List.generate(previewSampleCount, (i) => rawSamples[i * previewSampleRate * riff.format.blockAlign] / scaleFactor);
    return Tuple2(wavSamples, previewSampleRate);
  }
}
final audioResourcesManager = AudioResourcesManager();
