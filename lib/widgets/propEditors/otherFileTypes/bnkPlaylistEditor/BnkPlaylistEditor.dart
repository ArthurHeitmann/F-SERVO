
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/nestedNotifier.dart';
import '../../../../stateManagement/openFileTypes.dart';
import '../../../../utils/utils.dart';
import '../../../theme/customTheme.dart';
import 'BnkPlaylistEditorInheritedData.dart';
import 'BnkSegmentEditor.dart';
import 'audioSequenceController.dart';


class BnkPlaylistEditor extends StatefulWidget {
  final BnkFilePlaylistData playlist;

  const BnkPlaylistEditor({ super.key, required this.playlist });

  @override
  State<BnkPlaylistEditor> createState() => _BnkPlaylistEditorState();
}

class _BnkPlaylistEditorState extends State<BnkPlaylistEditor> {
  CurrentPlaybackItem? _currentPlaybackItem;
  final playbackMarker = PlaybackMarker(ValueNotifier(null), ValueNotifier(0));
  final ValueNotifier<double> msPerPix = ValueNotifier(1);
  final ValueNotifier<double> xOff = ValueNotifier(0);
  final selectedClipUuids = ValueNestedNotifier<String>([]);
  final scrollController = ScrollController();

  @override
  void initState() {
    widget.playlist.load().then((_) async {
      if (context.size == null)
        await waitForNextFrame();
      double maxDuration = 10000;
      var pendingSegments = widget.playlist.rootChild!.children.toList();
      while (pendingSegments.isNotEmpty) {
        var segment = pendingSegments.removeLast();
        if (segment.segment != null) {
          for (var track in segment.segment!.tracks) {
            for (var playlist in track.srcTrack.playlists) {
              maxDuration = max(maxDuration, playlist.fSrcDuration);
            }
          }
        }
        pendingSegments.addAll(segment.children);
      }
      maxDuration *= 1.25;
      var width = context.size?.width ?? 1000;
      msPerPix.value = maxDuration / width;
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlist.loadingState != LoadingState.loaded) {
      return Stack(
        children: const [
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent),
          ),
        ],
      );
    }
    return AudioEditorData(
      msPerPix: msPerPix,
      xOff: xOff,
      selectedClipUuids: selectedClipUuids,
      getClipByUuid: _getClipByUuid,
      child: AudioPlaybackScope(
        currentPlaybackItem: _currentPlaybackItem,
        playbackMarker: playbackMarker,
        setCurrentPlaybackItem: (item) {
          _currentPlaybackItem = item;
          setState(() {});
        },
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            xOff.value += details.delta.dx;
          },
          onVerticalDragUpdate: (details) {
            scrollController.jumpTo(clamp(scrollController.offset - details.delta.dy, 0, scrollController.position.maxScrollExtent));
          },
          behavior: HitTestBehavior.translucent,
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent)
                return;
              // zoom
              var scale = event.scrollDelta.dy / 100;
              msPerPix.value *= scale + 1;
              // offset
              var renderBox = context.findRenderObject() as RenderBox;
              var x = renderBox.globalToLocal(event.position).dx;
              var xOffDist = x - xOff.value;
              var xChange = xOffDist * -scale;
              if (scale < 0)  // magic numbers :)
                xChange *= 1.25;
              else
                xChange /= 1.2;
              xOff.value -= xChange;
            },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40,),
                  Stack(
                    children: [
                      BnkPlaylistChildEditor(
                        plSegment: widget.playlist.rootChild!
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: Tooltip(
                            message: "Update track durations",
                            waitDuration: const Duration(milliseconds: 500),
                            child: IconButton(
                              onPressed: () => widget.playlist.rootChild!.updateTrackDurations()
                                .then((_) => showToast("Updated track durations", const Duration(seconds: 2))),
                              splashRadius: 20,
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        )
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BnkTrackClip? _getClipByUuid(String uuid, [BnkPlaylistChild? playlistChild]) {
    playlistChild ??= widget.playlist.rootChild;
    if (playlistChild == null)
      return null;
    if (playlistChild.segment != null) {
      for (var track in playlistChild.segment!.tracks) {
        for (var clip in track.clips) {
          if (clip.uuid == uuid)
            return clip;
        }
      }
    }

    for (var child in playlistChild.children) {
      var clip = _getClipByUuid(uuid, child);
      if (clip != null)
        return clip;
    }

    return null;
  }
}

class BnkPlaylistChildEditor extends StatefulWidget {
  final BnkPlaylistChild plSegment;
  final int depth;

  const BnkPlaylistChildEditor({ super.key, required this.plSegment, this.depth = 0 });

  @override
  State<BnkPlaylistChildEditor> createState() => _BnkPlaylistChildEditorState();
}

class _BnkPlaylistChildEditorState extends State<BnkPlaylistChildEditor> with AudioPlayingWidget {
  bool isCollapsed = false;
  BnkPlaylistChild get plSegment => widget.plSegment;
  BnkSegmentData? get segment => widget.plSegment.segment;

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(onKey);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(onKey);
    onDispose();
    super.dispose();
  }

  @override
  PlaybackController makePlaybackController() {
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    PlaybackController playbackController;
    if (segment != null) {
      playbackController = BnkSegmentPlaybackController(plSegment, segment!);
      audioPlaybackScope.playbackMarker.segmentUuid.value = segment!.uuid;
    } else if (plSegment.children.every((c) => c.segment != null)) {
      var newController = MultiSegmentPlaybackController(plSegment);
      playbackController = newController;
      newController.currentSegmentStream.listen(onSegmentChange);
      if (plSegment.children.isNotEmpty)
        audioPlaybackScope.playbackMarker.segmentUuid.value = plSegment.children.first.segment!.uuid;
      else
        audioPlaybackScope.playbackMarker.segmentUuid.value = null;
    } else {
      throw Exception("Can't play this segment");
    }
    return playbackController;
  }

  @override
  Widget build(BuildContext context) {
    var inner = Column(
      children: [
        InkWell(
          onTap: () => setState(() => isCollapsed = !isCollapsed),
          child: Padding(
            padding: EdgeInsets.only(left: widget.depth * 20, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more),
                Flexible(
                  child: Text(
                    "${segment != null ? "Segment" : "Playlist"} (Loops: ${widget.plSegment.loops}) "
                    "${segment == null ? "(Reset type: ${widget.plSegment.resetType.name}) " : ""}"
                    "(ID: ${segment != null ? widget.plSegment.srcItem.segmentId : widget.plSegment.srcItem.playlistItemId})",
                    style: const TextStyle(fontFamily: "FiraCode"),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8,),
                ChangeNotifierBuilder(
                  notifiers: segment?.tracks.map((t) => t.hasSourceChanged).toList(),
                  builder: (context) => segment?.tracks.any((t) => t.hasSourceChanged.value) == true
                    ? Tooltip(
                      message: "Source changed",
                      waitDuration: const Duration(milliseconds: 500),
                      child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.8)),
                          ),
                      ),
                    )
                    : const SizedBox()
                ),
                if (segment != null || widget.plSegment.children.isNotEmpty && widget.plSegment.children.every((c) => c.segment != null)) ...[
                  StreamBuilder(
                    stream: currentPlaybackItem?.playbackController.isPlayingStream,
                    builder: (context, snapshot) {
                      return IconButton(
                        iconSize: 20,
                        splashRadius: 20,
                        icon: currentPlaybackItem?.playbackController.isPlaying == true
                          ? const Icon(Icons.pause)
                          : const Icon(Icons.play_arrow),
                        onPressed: togglePlayback,
                      );
                    }
                  ),
                  StreamBuilder(
                    key: ValueKey(currentPlaybackItem?.playbackController.positionStream),
                    stream: currentPlaybackItem?.playbackController.positionStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        var pos = snapshot.data as double;
                        return Text(formatDuration(Duration(milliseconds: pos.toInt())));
                      }
                      return const SizedBox();
                    }
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isCollapsed) ...[
          if (segment != null)
            BnkSegmentEditor(
              segment: segment!,
              viewNotifiers: [
                AudioEditorData.of(context).msPerPix,
                AudioEditorData.of(context).xOff,
              ],
              playbackMarker: AudioPlaybackScope.of(context).playbackMarker,
            ),
            for (int i = 0; i < widget.plSegment.children.length; i++)
              BnkPlaylistChildEditor(
                plSegment: widget.plSegment.children[i],
                depth: widget.depth + 1,
              )
        ],
      ],
    );
    if (widget.plSegment.children.isNotEmpty) {
      return Material(
        color: getTheme(context).actionBgColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: getTheme(context).propBorderColor!),
            ),
          ),
          child: inner
        ),
      );
    }
    return inner;
  }
}
