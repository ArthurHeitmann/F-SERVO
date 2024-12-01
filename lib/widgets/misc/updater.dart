
import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../../version/installRelease.dart';
import '../../version/retrieveReleases.dart';
import '../../version/version.dart';
import '../theme/customTheme.dart';

class VersionUpdaterUi extends StatefulWidget {
  const VersionUpdaterUi({super.key});

  @override
  State<VersionUpdaterUi> createState() => _VersionUpdaterUiState();
}

class _VersionUpdaterUiState extends State<VersionUpdaterUi> {
  List<GitHubReleaseInfo>? releases;
  Future<void>? releasesFuture;
  String selectedBranch = version.branch;
  GitHubReleaseInfo? selectedRelease;
  static StreamController<String> updateStepStream = StreamController.broadcast();
  static StreamController<double> updateProgressStream = StreamController.broadcast();
  static bool isUpdating  = false;
  static String? errorMessage;

  void loadReleases() {
    releasesFuture = retrieveReleases()
      .then((value) {
        releases = value;
        selectedRelease = releases!
          .where((e) => e.version == version)
          .firstOrNull;
        setState(() {});
      })
      .catchError((e) {
        releases = null;
        selectedRelease = null;
        showToast("Failed to load GitHub releases");
        print("Failed to load GitHub releases: $e");
        setState(() {});
      });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Game: "),
            PopupMenuButton<String>(
              initialValue: selectedBranch,
              onSelected: (v) {
                setState(() => selectedBranch = v);
              },
              itemBuilder: (context) => branches.map((branch) => PopupMenuItem(
                value: branch,
                height: 20,
                child: Text(branchToGameName[branch] ?? branch),
              )).toList(),
              position: PopupMenuPosition.under,
              constraints: BoxConstraints.tightFor(width: 190),
              popUpAnimationStyle: AnimationStyle(duration: Duration.zero),
              tooltip: "",
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    branchToGameName[selectedBranch] ?? selectedBranch,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text("Version: "),
            FutureBuilder(
              future: releasesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) {
                  return TextButton(
                    onPressed: snapshot.connectionState == ConnectionState.waiting ? null : loadReleases,
                    child: const Text("Load versions"),
                  );
                }
                return PopupMenuButton<GitHubReleaseInfo>(
                  initialValue: selectedRelease,
                  onSelected: (v) {
                    setState(() => selectedRelease = v);
                  },
                  itemBuilder: (context) => releases!.where((r) => r.version?.branch == selectedBranch).map((release) => PopupMenuItem(
                    value: release,
                    height: 20,
                    child: Text(release.version!.toUiString(version)),
                  )).toList(),
                  position: PopupMenuPosition.under,
                  constraints: BoxConstraints(maxWidth: 250, maxHeight: 200),
                  popUpAnimationStyle: AnimationStyle(duration: Duration.zero),
                  tooltip: "",
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        selectedRelease?.version.toString() ?? version.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                );
              }
            ),
          ],
        ),
        if (selectedRelease != null && selectedRelease!.version! < branchFirstVersionedRelease[selectedRelease!.version!.branch]!)
          Text("Warning: Selected version does not have a built in updater", style: TextStyle(color: getTheme(context).titleBarButtonCloseColor)),
        if (selectedRelease != null && selectedRelease!.version != version)
          TextButton(
            onPressed: isUpdating ? null : () {
              isUpdating = true;
              errorMessage = null;
              installRelease(selectedRelease!, updateStepStream, updateProgressStream)
                .catchError((e) {
                  errorMessage = e.toString();
                  setState(() {});
                })
                .whenComplete(() {
                  isUpdating = false;
                  setState(() {});
                });
              setState(() {});
            },
            child: Text("Update to ${selectedRelease!.version}"),
          ),
        const SizedBox(height: 16),
        if (isUpdating)
          StreamBuilder(
            stream: updateStepStream.stream,
            builder: (context, stepSnapshot) {
              return StreamBuilder(
                stream: updateProgressStream.stream,
                builder: (context, progressSnapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 5,
                        child: LinearProgressIndicator(
                          value: progressSnapshot.data ?? 0,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(stepSnapshot.data ?? "Updating..."),
                    ],
                  );
                }
              );
            }
          ),
        if (errorMessage != null)
          Text(errorMessage!, style: TextStyle(color: getTheme(context).titleBarButtonCloseColor)),
      ],
    );
  }
}
