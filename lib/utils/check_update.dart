import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../app_config.dart';

Future<UpdateInfo?> checkUpdate({BaseDeviceInfo? deviceInfo}) async {
  final response = await http.get(appConfig.updateUri,
      headers: {'Accept': 'application/vnd.github+json'});
  dynamic updateBody;
  try {
    updateBody = jsonDecode(response.body);
  } catch (e) {
    return null; // can't parse response
  }

  // Support two manifest types:
  // 1) GitHub release JSON (object with 'tag_name' and 'assets')
  // 2) Simple manifest JSON { version, url, sha256, notes }
  Map update;
  bool isSimpleManifest = false;
  if (updateBody is Map &&
      updateBody.containsKey('version') &&
      updateBody.containsKey('url')) {
    isSimpleManifest = true;
  }

  if (isSimpleManifest) {
    // map to UpdateInfo if version is newer
    final manifest = updateBody as Map;
    Version remoteVersion;
    try {
      remoteVersion = Version.parse(manifest['version'].toString());
    } catch (e) {
      return null;
    }

    Version currentVersion;
    try {
      currentVersion = Version.parse(appConfig.codeName);
    } catch (e) {
      currentVersion = Version(0, 0, 0);
    }

    if (remoteVersion.compareTo(currentVersion) <= 0) return null;

    return UpdateInfo(
      name: manifest['version'].toString(),
      publishedAt: manifest['publishedAt'] ?? '',
      body: manifest['notes'] ?? '',
      downloadUrl: manifest['url'],
      downloadCount: 0,
    );
  }

  update = updateBody as Map;
  // Defensive parsing: ensure codeName and tag_name are valid semantic versions
  Version currentVersion;
  try {
    currentVersion = Version.parse(appConfig.codeName);
  } catch (e) {
    currentVersion = Version(0, 0, 0);
  }

  Version remoteVersion;
  try {
    final tag = (update['tag_name'] ?? '').toString();
    if (tag.isEmpty || tag == 'null') throw FormatException('empty tag');
    remoteVersion = Version.parse(tag.replaceAll('v', ''));
  } catch (e) {
    // Couldn't parse remote version; abort update check gracefully
    return null;
  }

  int comparison = remoteVersion.compareTo(currentVersion);

  if (comparison > 0) {
    if (deviceInfo == null) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      deviceInfo = await deviceInfoPlugin.deviceInfo;
    }

    Map? supportedAsset;
    List assets = update['assets'];
    if (Platform.isAndroid) {
      List<String> supportedAbis =
          deviceInfo.data['supportedAbis'].cast<String>();

      for (var supportedAbi in supportedAbis) {
        List supportedAssets = assets
            .where((asset) => asset['name'].contains(supportedAbi))
            .toList();
        if (supportedAssets.isNotEmpty) {
          supportedAsset = supportedAssets.first;
          break;
        }
      }
    } else if (Platform.isWindows) {
      List supportedAssets = assets
          .where(
            (asset) =>
                asset["content_type"] == "application/x-msdownload" ||
                asset['name'].toString().endsWith('.exe'),
          )
          .toList();
      supportedAsset =
          supportedAssets.isNotEmpty ? supportedAssets.first : null;
    }
    if (supportedAsset == null) return null;
    int downloadCount = 0;
    for (var asset in assets) {
      downloadCount += (asset['download_count'] as int);
    }
    return UpdateInfo(
      name: update['name'],
      publishedAt: update['published_at'],
      body: update['body'],
      downloadUrl: supportedAsset['browser_download_url'],
      downloadCount: downloadCount,
    );
  } else {
    return null;
  }
}

class UpdateInfo {
  String name;
  String publishedAt;
  String body;
  String downloadUrl;
  int downloadCount;
  String? assetName;
  UpdateInfo({
    required this.name,
    required this.publishedAt,
    required this.body,
    required this.downloadCount,
    required this.downloadUrl,
    this.assetName,
  });
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'publishedAt': publishedAt,
      'body': body,
      'downloadUrl': downloadUrl,
      'downloadCount': downloadCount,
    };
  }
}
