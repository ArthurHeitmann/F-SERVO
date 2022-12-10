
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/openFileTypes.dart';

abstract class PlaybackController {
  final StreamController<double> _positionStream = StreamController<double>.broadcast();
  final StreamController<bool> _isPlayingStream = StreamController<bool>.broadcast();
  Stream<double> get positionStream => _positionStream.stream;
  Stream<bool> get isPlayingStream => _isPlayingStream.stream;
  final void Function()? _onEnd;
  double _duration = 0;

  PlaybackController([this._onEnd]);
  
  void play();
  void pause();
  void seekTo(double ms);
  
  bool get isPlaying;
  Future<double> get position;
  double get duration => _duration;

  @mustCallSuper
  void dispose() {
    _positionStream.close();
    _isPlayingStream.close();
  }
}

class ClipPlaybackController extends PlaybackController {
  final BnkTrackClip clip;
  final AudioPlayer _player = AudioPlayer();
  Timer? _endTimer;
  

  ClipPlaybackController(this.clip, [super.onEnd]) {
    _duration = clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value.toDouble();
    _player.setSourceDeviceFile(clip.resource!.wavPath)
      .then((_) => _player.seek(Duration(microseconds: (clip.beginTrim.value * 1000).toInt())));
    _player.onPositionChanged.listen((Duration position) {
      _positionStream.add(position.inMilliseconds.toDouble());
    });
    _player.onPlayerStateChanged.listen((state) {
      _isPlayingStream.add(state == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      _onEnd?.call();
    });
  }

  void _onEndTimer() async {
    // print("${DateTime.now()} clip end timer");
    await _player.pause();
    _endTimer?.cancel();
    _onEnd?.call();
  }

  @override
  void play() async {
    // print("${DateTime.now()} clip play");
    _player.resume();
    var pos = await _player.getCurrentPosition();
    var endIn = duration - pos!.inMicroseconds / 1000 + clip.beginTrim.value;
    _endTimer = Timer(Duration(microseconds: (endIn * 1000).toInt()), _onEndTimer);
  }

  @override
  void pause() {
    // print("${DateTime.now()} clip pause");
    _player.pause();
    _endTimer?.cancel();
  }

  @override
  void seekTo(double ms) {
    // print("${DateTime.now()} clip seek to $ms");
    var pos = ms + clip.beginTrim.value;
    _player.seek(Duration(microseconds: (pos * 1000).toInt()));
    if (isPlaying) {
      _endTimer?.cancel();
      play();
    }
  }

  @override
  bool get isPlaying => _player.state == PlayerState.playing;

  @override
  Future<double> get position async {
    var posDur = await _player.getCurrentPosition() ?? Duration.zero;
    var pos = posDur.inMicroseconds / 1000 - clip.beginTrim.value;
    return pos;
  }

  @override
  void dispose() {
    super.dispose();
    // print("${DateTime.now()} clip dispose");
    _player.dispose();
    _endTimer?.cancel();
  }
}

class GapPlaybackController extends PlaybackController {
  /// called when this gap has finished "playing"
  Timer? _endTimer;
  /// called every 100ms to update the position
  Timer? _positionTimer;
  /// the position of the playback
  double _position = 0;
  /// The time the playback started. Used to calculate the position
  DateTime _playStartTime = DateTime.now();
  bool _isPlaying = false;

  GapPlaybackController(double duration, [super.onEnd]) {
    _duration = duration;
    _positionStream.add(0);
    _isPlayingStream.add(false);
  }

  @override
  void play() {
    // print("${DateTime.now()} gap play");
    var endIn = duration - _position;
    _playStartTime = DateTime.now();
    _endTimer = Timer(Duration(microseconds: (endIn * 1000).toInt()), () {
      // print("${DateTime.now()} gap end timer");
      _endTimer?.cancel();
      _positionTimer?.cancel();
      _positionStream.add(duration);
      _isPlaying = false;
      _isPlayingStream.add(false);
      _onEnd?.call();
    });
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _position = DateTime.now().difference(_playStartTime).inMicroseconds / 1000;
      _positionStream.add(_position);
    });
    _isPlaying = true;
    _isPlayingStream.add(true);
  }

  @override
  void pause() {
    // print("${DateTime.now()} gap pause");
    _endTimer?.cancel();
    _positionTimer?.cancel();
    _isPlaying = false;
    _isPlayingStream.add(false);
  }

  @override
  void seekTo(double ms) {
    // print("${DateTime.now()} gap seek to $ms");
    _position = ms;
    _positionStream.add(_position);
    if (_isPlaying) {
      _endTimer?.cancel();
      _positionTimer?.cancel();
      play();
    }
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<double> get position async => _position;

  @override
  void dispose() {
    super.dispose();
    // print("${DateTime.now()} gap dispose");
    _endTimer?.cancel();
    _positionTimer?.cancel();
  }
}

class BnkTrackPlaybackController extends PlaybackController {
  final List<PlaybackController> _controllers = [];
  int _currentControllerIndex = 0;

  BnkTrackPlaybackController(BnkTrackData track, [super.onEnd]) {
    var clips = track.clips.toList();
    clips.sort((a, b) {
      var aStart = a.xOff.value + a.beginTrim.value;
      var bStart = b.xOff.value + b.beginTrim.value;
      return aStart.compareTo(bStart);
    });
    var firstClipStart = clips.first.xOff.value + clips.first.beginTrim.value;
    if (firstClipStart > 0) {
      var gapController = GapPlaybackController(firstClipStart.toDouble(), _onClipEnd);
      _setupControllerEvents(gapController);
      _controllers.add(gapController);
    }
    for (int i = 0; i < clips.length; i++) {
      var clip = clips[i];
      var controller = ClipPlaybackController(clip, _onClipEnd);
      _setupControllerEvents(controller);
      _controllers.add(controller);
      var nextClip = i < clips.length - 1 ? clips[i + 1] : null;
      if (nextClip == null)
        continue;
      var clipEnd = clip.xOff.value + clip.beginTrim.value + clip.endTrim.value;
      var nextClipStart = nextClip.xOff.value + nextClip.beginTrim.value;
      var gapDuration = nextClipStart - clipEnd;
      if (gapDuration == 0)
        continue;
      var gapController = GapPlaybackController(gapDuration.toDouble(), _onClipEnd);
      _setupControllerEvents(gapController);
      _controllers.add(gapController);
    }
    _duration = _controllers.map((e) => e.duration).reduce((value, element) => value + element);
    seekTo(0);
  }

  void _setupControllerEvents(PlaybackController controller) {
    controller.positionStream.listen(_onClipPositionChange);
  }

  void _onClipPositionChange(_) async {
    _positionStream.add(await position);
  }

  void _onClipEnd() {
    // print("${DateTime.now()} clip end $_currentControllerIndex");
    _controllers[_currentControllerIndex].pause();
    _controllers[_currentControllerIndex].seekTo(0);
    _currentControllerIndex++;
    if (_currentControllerIndex >= _controllers.length) {
      _onEnd?.call();
      _currentControllerIndex = 0;
      _isPlayingStream.add(false);
      seekTo(0);
      return;
    }
    _controllers[_currentControllerIndex].play();
  }

  @override
  void play() {
    // print("${DateTime.now()} track play");
    _controllers[_currentControllerIndex].play();
    _isPlayingStream.add(true);
  }

  @override
  void pause() {
    // print("${DateTime.now()} track pause");
    _controllers[_currentControllerIndex].pause();
    _isPlayingStream.add(false);
  }

  @override
  void seekTo(double ms) {
    // print("${DateTime.now()} track seek to $ms");
    var position = 0.0;
    for (int i = 0; i < _controllers.length; i++) {
      var controller = _controllers[i];
      var controllerDuration = controller.duration;
      if (position + controllerDuration > ms) {
        _currentControllerIndex = i;
        controller.seekTo(ms - position);
        break;
      }
      position += controllerDuration;
    }
  }

  @override
  bool get isPlaying => _controllers[_currentControllerIndex].isPlaying;

  @override
  Future<double> get position async {
    var position = 0.0;
    for (int i = 0; i < _currentControllerIndex; i++) {
      position += _controllers[i].duration;
    }
    position += await _controllers[_currentControllerIndex].position;
    return position;
  }

  @override
  void dispose() {
    super.dispose();
    // print("${DateTime.now()} track dispose");
    for (var controller in _controllers)
      controller.dispose();
  }
}

class BnkSegmentPlaybackController extends PlaybackController {
  final List<PlaybackController> _tracks = [];
  late final bool loop;
  NumberProp? _entryCue;
  NumberProp? _exitCue;
  final void Function()? _onExitCue;
  bool _isPlaying = false;
  double _positionBeforePlay = 0;
  DateTime _playStartTime = DateTime.now();
  Timer? _exitCueTimer;
  Timer? _endTimer;
  Timer? _positionUpdateTimer;
  double get _maxDuration => max(duration, _exitCue?.value.toDouble() ?? 0);

  BnkSegmentPlaybackController(
    BnkPlaylistChild plChild,
    BnkSegmentData segment,
    {
      void Function()? onExitCue,
      void Function()? onEnd,
    }
  ) :
    _onExitCue = onExitCue,
    super(onEnd) {
    var trackDurations = segment.tracks.map((track) {
      var clipEnds = track.clips.map((e) => e.xOff.value + e.srcDuration.value + e.endTrim.value);
      var maxEnd = clipEnds.reduce(max);
      return maxEnd;
    });
    _duration = trackDurations.reduce(max).toDouble();
    loop = plChild.srcItem.loop == 0;
    var markers = segment.markers;
    if (markers.length >= 2) {
      _entryCue = markers.first.pos;
      _exitCue = markers.last.pos;
    }
    for (var track in segment.tracks) {
      var controller = BnkTrackPlaybackController(track);
      _tracks.add(controller);
    }
    seekTo(_entryCue?.value.toDouble() ?? 0);
  }

  void _onExitCueCb() {
    // print("${DateTime.now()} segment exit cue");
    _exitCueTimer?.cancel();
    _onExitCue?.call();
    if (loop) {
      seekTo(_entryCue?.value.toDouble() ?? 0);
      play();
    }
  }

  @override
  void play() {
    // print("${DateTime.now()} segment play");
    _playStartTime = DateTime.now();
    var pos = getPos();
    for (var track in _tracks) {
      if (pos < track.duration)
        track.play();
    }
    _isPlaying = true;
    _isPlayingStream.add(true);
    _updatePlayTimers();
  }

  void _updatePlayTimers() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      var diff = DateTime.now().difference(_playStartTime).inMicroseconds / 1000;
      var position = _positionBeforePlay + diff;
      _positionStream.add(position);
    });
    var timeToEnd = _maxDuration - _positionBeforePlay;
    _endTimer?.cancel();
    _endTimer = Timer(Duration(microseconds: (timeToEnd * 1000).toInt()), () {
      // print("${DateTime.now()} segment end");
      _isPlaying = false;
      _isPlayingStream.add(false);
      _positionUpdateTimer?.cancel();
      _exitCueTimer?.cancel();
      if (!loop)
        _onEnd?.call();
    });
    if (_exitCue != null) {
      var timeToExitCue = _exitCue!.value - _positionBeforePlay;
      _exitCueTimer?.cancel();
      _exitCueTimer = Timer(Duration(microseconds: (timeToExitCue * 1000).toInt()), _onExitCueCb);
    }
  }

  @override
  void pause() {
    // print("${DateTime.now()} segment pause");
    for (var e in _tracks)
      e.pause();
    _positionBeforePlay += DateTime.now().difference(_playStartTime).inMicroseconds / 1000;
    _isPlaying = false;
    _isPlayingStream.add(false);
    _positionUpdateTimer?.cancel();
    _exitCueTimer?.cancel();
  }

  @override
  void seekTo(double ms) {
    // print("${DateTime.now()} segment seek to $ms");
    _positionBeforePlay = ms;
    var pos = getPos();
    for (var e in _tracks) {
      if (pos < e.duration)
        e.seekTo(ms);
    }
    _positionStream.add(_positionBeforePlay);
    _playStartTime = DateTime.now();
    _positionUpdateTimer?.cancel();
    _endTimer?.cancel();
    _exitCueTimer?.cancel();
    if (_isPlaying) {
      _playStartTime = DateTime.now();
      _updatePlayTimers();
    }
  }

  @override
  bool get isPlaying => _isPlaying;

  double getPos() {
    if (_isPlaying) {
      var timeSincePlay = DateTime.now().difference(_playStartTime).inMicroseconds / 1000;
      var position = _positionBeforePlay + timeSincePlay;
      return position;
    } else {
      return _positionBeforePlay;
    }
  }

  @override
  Future<double> get position async => getPos();

  @override
  void dispose() {
    super.dispose();
    // print("${DateTime.now()} segment dispose");
    for (var track in _tracks)
      track.dispose();
    _positionUpdateTimer?.cancel();
    _exitCueTimer?.cancel();
  }
}

class MultiSegmentPlaybackController extends PlaybackController {
  final List<BnkSegmentPlaybackController> _segments = [];
  int _currentSegment = 0;

  MultiSegmentPlaybackController(BnkPlaylistChild plChild) {
    for (var child in plChild.children) {
      var controller = BnkSegmentPlaybackController(plChild, child.segment!, onExitCue: _onSegmentEnd);
      controller.positionStream.listen((_) async {
        if (controller != _segments[_currentSegment])
          return;
        _positionStream.add(await _segments[_currentSegment].position);
      });
      _segments.add(controller);
    }
  }

  void _onSegmentEnd() {
    if (_currentSegment < _segments.length - 1) {
      _currentSegment++;
      _segments[_currentSegment].play();
    } else {
      _onEnd?.call();
    }
  }
  
  @override
  void dispose() {
    super.dispose();
    for (var segment in _segments)
      segment.dispose();
  }

  @override
  bool get isPlaying => _segments[_currentSegment].isPlaying;

  @override
  void pause() {
    _segments[_currentSegment].pause();
  }

  @override
  void play() {
    _segments[_currentSegment].play();
  }

  @override
  Future<double> get position => _segments[_currentSegment].position;
  
  @override
  get duration => _segments[_currentSegment].duration;

  @override
  void seekTo(double ms) {
    _segments[_currentSegment].seekTo(ms);
  }

  void seekToSegment(int i) {
    if (i == _currentSegment)
      return;
    if (isPlaying)
      _segments[_currentSegment].pause();
    _currentSegment = i;
    _segments[_currentSegment].seekTo(0);
  }
}
