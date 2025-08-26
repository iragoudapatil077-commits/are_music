import 'dart:collection';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:are_music/ytmusic/ytmusic.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'file_storage.dart';
import 'settings_manager.dart';
import 'stream_client.dart';
import 'database_helper.dart';

Box _box = Hive.box('DOWNLOADS');
YoutubeExplode ytExplode = YoutubeExplode();

class DownloadManager {
  Client client = Client();
  ValueNotifier<List<Map>> downloads = ValueNotifier([]);
  final int maxConcurrentDownloads = 3; // Limit concurrent downloads
  int _activeDownloads = 0;
  final Queue<Map> _downloadQueue = Queue<Map>(); // Queue for pending downloads

  DownloadManager() {
    downloads.value = _box.values.toList().cast<Map>();
    _box.listenable().addListener(() {
      downloads.value = _box.values.toList().cast<Map>();
    });
  }

  Future<void> downloadSong(Map song) async {
    if (_activeDownloads >= maxConcurrentDownloads) {
      _downloadQueue.add(song); // Add to queue if limit reached
      return;
    }

    _activeDownloads++;
    try {
      if (!(await FileStorage.requestPermissions())) {
        // permission denied, ensure we schedule next
        _activeDownloads--;
        _downloadNext();
        return;
      }

      AudioOnlyStreamInfo audioSource;
      try {
        audioSource = await _getSongInfo(song['videoId'],
            quality:
                GetIt.I<SettingsManager>().downloadQuality.name.toLowerCase());
      } catch (e) {
        // failed to get stream info
        print(
            'DownloadManager: _getSongInfo failed for ${song['videoId']}: $e');
        await _box.delete(song['videoId']);
        _activeDownloads--;
        _downloadNext();
        return;
      }

      // audioSource is never null here because _getSongInfo either returns
      // a valid AudioOnlyStreamInfo or throws.

      int start = 0;
      int total = audioSource.size.totalBytes;

      Stream<List<int>> stream = AudioStreamClient()
          .getAudioStream(audioSource, start: start, end: total);

      await _box.put(song['videoId'], {
        ...song,
        'status': 'PROCESSING',
        'progress': 0,
      });

      // Write to temp file as chunks to avoid holding whole file in memory
      final musicDir = GetIt.I<FileStorage>().storagePaths.musicPath;
      final safeId = song['videoId'] ?? DateTime.now().millisecondsSinceEpoch;
      final tmpPath = p.join(musicDir, '$safeId.tmp');
      final tmpFile = File(tmpPath);
      if (tmpFile.existsSync()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }

      IOSink? sink;
      int received = 0;
      try {
        sink = tmpFile.openWrite();
      } catch (e) {
        print(
            'DownloadManager: Failed to open temp file for ${song['videoId']}: $e');
        await _box.delete(song['videoId']);
        _activeDownloads--;
        _downloadNext();
        return;
      }

      // Throttle frequent Hive writes to avoid file locking on desktop.
      int lastProgressUpdate = 0;
      stream.listen(
        (data) async {
          try {
            sink?.add(data);
            received += data.length;
            final int progress = ((received / total) * 100).toInt();
            // update hive only if progress changed by at least 1% to reduce IO
            if (progress != lastProgressUpdate) {
              lastProgressUpdate = progress;
              try {
                final key =
                    song['videoId'] ?? DateTime.now().millisecondsSinceEpoch;
                await _box.put(key, {
                  ...song,
                  'status': 'DOWNLOADING',
                  'progress': progress,
                });
              } catch (e) {
                // log but don't fail entire download on hive write error
                print(
                    'DownloadManager: hive write error for ${song['videoId']}: $e');
              }
            }
          } catch (e) {
            print(
                'DownloadManager: error writing chunk for ${song['videoId']}: $e');
          }
        },
        onDone: () async {
          try {
            await sink?.close();
            final actual = await tmpFile.length();
              if (actual == total) {
              // read bytes and use existing saveMusic to write tags etc.
              final bytes = await tmpFile.readAsBytes();
              File? file = await GetIt.I<FileStorage>().saveMusic(bytes, song);
              if (file != null) {
                try {
                  final key =
                      song['videoId'] ?? DateTime.now().millisecondsSinceEpoch;
                  await _box.put(key, {
                    ...song,
                    'status': 'DOWNLOADED',
                    'progress': 100,
                    'path': file.path,
                    'timestamp': DateTime.now().millisecondsSinceEpoch
                  });
                  // Also ensure DB has record (redundant but safe)
                  try {
                    await DatabaseHelper.instance.insertMusicFile(file);
                  } catch (e) {
                    // ignore DB errors
                  }
                } catch (e) {
                  print('DownloadManager: hive put after save failed: $e');
                }
              } else {
                await _box.delete(song['videoId']);
              }
              try {
                await tmpFile.delete();
              } catch (_) {}
            } else {
              print(
                  'DownloadManager: expected $total bytes but got $actual for ${song['videoId']}');
              await _box.delete(song['videoId']);
            }
          } catch (e) {
            print(
                'DownloadManager: onDone handler error for ${song['videoId']}: $e');
            await _box.delete(song['videoId']);
          } finally {
            _activeDownloads--;
            _downloadNext();
          }
        },
        onError: (err) async {
          try {
            await sink?.close();
            if (await tmpFile.exists()) await tmpFile.delete();
          } catch (_) {}
          print('DownloadManager: stream error for ${song['videoId']}: $err');
          await _box.delete(song['videoId']);
          _activeDownloads--;
          _downloadNext();
        },
      );
    } catch (e) {
      print('DownloadManager: unexpected error for ${song['videoId']}: $e');
      await _box.delete(song['videoId']); // Handle errors by removing entry
      if (_activeDownloads > 0) _activeDownloads--;
      _downloadNext();
    }
  }

  void _downloadNext() {
    if (_downloadQueue.isNotEmpty &&
        _activeDownloads < maxConcurrentDownloads) {
      downloadSong(_downloadQueue.removeFirst());
    }
  }

  Future<String> deleteSong(String key, String path) async {
    await _box.delete(key);
    await File(path).delete();
    return 'Song deleted successfully.';
  }

  updateStatus(String key, String status) {
    Map? song = _box.get(key);
    if (song != null) {
      song['status'] = status;
      _box.put(key, song);
    }
  }

  Future<void> downloadPlaylist(Map playlist) async {
    List songs =
        await GetIt.I<YTMusic>().getPlaylistSongs(playlist['playlistId']);
    for (Map song in songs) {
      await downloadSong(song); // Queue each song download
    }
  }

  Future<AudioOnlyStreamInfo> _getSongInfo(String videoId,
      {String quality = 'high'}) async {
    try {
      StreamManifest manifest =
          await ytExplode.videos.streamsClient.getManifest(videoId);
      // Prefer mp4 container audio-only streams; fall back to any audio-only
      List<AudioOnlyStreamInfo> streamInfos = manifest.audioOnly
          .where((a) => a.container == StreamContainer.mp4)
          .toList();

      if (streamInfos.isEmpty) {
        streamInfos = manifest.audioOnly.toList();
      }

      if (streamInfos.isEmpty) {
        throw Exception('No audio streams available for $videoId');
      }

      // sort by bitrate ascending (type-safe)
      streamInfos.sort((a, b) {
        final int ai = (a.bitrate is int) ? (a.bitrate as int) : 0;
        final int bi = (b.bitrate is int) ? (b.bitrate as int) : 0;
        return ai.compareTo(bi);
      });
      return quality == 'low' ? streamInfos.first : streamInfos.last;
    } catch (e) {
      rethrow;
    }
  }
}
