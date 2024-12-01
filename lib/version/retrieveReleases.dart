
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'version.dart';

const _apiEndpoint = "https://api.github.com/repos/ArthurHeitmann/F-SERVO/releases";

class GitHubReleaseInfo {
  final String tagName;
  final String url;
  final DateTime publishedAt;
  final String downloadUrl;
  final int downloadSize;
  FServoVersion? _version;
  FServoVersion? get version => _version ??= FServoVersion.parse(tagName);

  GitHubReleaseInfo(this.tagName, this.url, this.publishedAt, this.downloadUrl, this.downloadSize);
}

Future<List<GitHubReleaseInfo>> retrieveReleases() async {
  var response = await http.get(Uri.parse(_apiEndpoint));
  if (response.statusCode != 200)
    throw Exception("Failed to retrieve releases: ${response.body}");
  var json = jsonDecode(response.body);
  var releases = (json as List)
    .map((e) {
      return GitHubReleaseInfo(
        e["tag_name"],
        e["html_url"],
        DateTime.parse(e["published_at"]),
        (e["assets"] as List).firstOrNull?["browser_download_url"],
        (e["assets"] as List).firstOrNull?["size"],
      );
    })
    .where((e) => e.version != null)
    .toList();
  releases.sort((a, b) => b.version!.compareTo(a.version!));
  return releases;
}

GitHubReleaseInfo? updateRelease(List<GitHubReleaseInfo> releases, FServoVersion currentVersion) {
  return releases
    .where((e) => e.version != null)
    .where((e) => e.version!.branch == currentVersion.branch)
    .where((e) => e.version! > currentVersion)
    .firstOrNull;
}
