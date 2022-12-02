
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../fileTypeUtils/audio/wemToWavConverter.dart';
import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class WemPreviewButton extends StatefulWidget {
  final String wemPath;

  const WemPreviewButton({ super.key, required this.wemPath });

  @override
  State<WemPreviewButton> createState() => _WemPreviewButtonState();
}

class _WemPreviewButtonState extends State<WemPreviewButton> {
  String? wavPath;
  AudioPlayer? player;
  bool isLoading = false;

  void togglePlay() async {
    if (wavPath == null || player == null)
      await loadWav();
    if (player!.state == PlayerState.playing)
      await player?.pause();
    else
      await player?.resume();
  }

  Future<void> loadWav() async {
    try {
      setState(() => isLoading = true);
      wavPath = await wemToWavTmp(widget.wemPath, "hierarchyPreview");
      player = AudioPlayer();
      player!.onPlayerStateChanged.listen((state) {
        if (mounted)
          setState(() {});
      });
      await player!.setSourceDeviceFile(wavPath!);
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      showToast("Error loading WEM file");
      rethrow;
    }
  }

  @override
  void dispose() {
    player?.dispose();
    if (wavPath != null)
      File(wavPath!).delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Icon icon;
    if (isLoading)
      icon = const Icon(Icons.hourglass_empty, size: 14);
    else if (player?.state == PlayerState.playing)
      icon = const Icon(Icons.pause, size: 15);
    else
      icon = const Icon(Icons.play_arrow, size: 15);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: getTheme(context).textColor!.withOpacity(0.333)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: togglePlay,
          child: icon,
        ),
      ),
    );
  }
}
