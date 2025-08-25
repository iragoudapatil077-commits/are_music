import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../../services/file_scanner.dart';
import '../../services/music_library_provider.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import '../../services/media_player.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audiotags/audiotags.dart';
import 'dart:typed_data';

class AllMusicScreen extends StatefulWidget {
  const AllMusicScreen({super.key});

  @override
  State<AllMusicScreen> createState() => _AllMusicScreenState();
}

class _AllMusicScreenState extends State<AllMusicScreen> {
  final Map<String, Uint8List?> _albumArts = {};

  Future<void> _fetchAlbumArt(String path) async {
    if (_albumArts.containsKey(path)) return;
    try {
      final tags = await AudioTags.read(path);
      if (!mounted) return;
      if (tags != null && tags.pictures.isNotEmpty) {
        setState(() {
          _albumArts[path] = tags.pictures.first.bytes;
        });
      } else {
        setState(() {
          _albumArts[path] = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _albumArts[path] = null;
      });
    }
  }

  Future<void> _refreshMusic(BuildContext context) async {
    await Provider.of<MusicLibraryProvider>(context, listen: false)
        .scanAllMusicFiles(FileScanner.scanAllMusicFiles);
  }

  Future<void> _playFile(String path) async {
    try {
      final player = GetIt.I<MediaPlayer>().player;

      // Stop current playback before starting metadata fetch
      await player.stop();

      // Fetch metadata first
      final tags = await AudioTags.read(path);
      final fileName = path.split('/').last;

      // Fetch metadata first with robust error handling
      String title = fileName;
      String artist = 'Unknown Artist';
      String album = 'Local Music';

      if (tags != null) {
        try {
          // Try to get title from the file name first
          final parts = fileName.split(' - ');
          if (parts.length > 1) {
            artist = parts[0].trim();
            title = parts[1].replaceAll(RegExp(r'\.[^.]+$'), '').trim();
          } else {
            title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
          }

          // If we have pictures, this is likely a tagged file, so use its title
          if (tags.pictures.isNotEmpty) {
            final songTitle = tags.title;
            if (songTitle != null && songTitle.isNotEmpty) {
              title = songTitle;
            }
          }
        } catch (e) {
          // If tag parsing fails, try filename parsing
          try {
            final parts = fileName.split(' - ');
            if (parts.length > 1) {
              artist = parts[0].trim();
              title = parts[1].replaceAll(RegExp(r'\.[^.]+$'), '').trim();
            } else {
              title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
            }
          } catch (e) {
            // If all parsing fails, use filename as title
            title = fileName;
          }
        }
      }

      // Handle album art
      Uint8List? albumArt = _albumArts[path];
      if (albumArt == null && tags?.pictures.isNotEmpty == true) {
        albumArt = tags!.pictures.first.bytes;
        setState(() {
          _albumArts[path] = albumArt;
        });
      }

      String? artFilePath;
      if (albumArt != null) {
        // Save album art to a safe system temp file and use its file path
        try {
          final tempDir = Directory.systemTemp;
          final artFile =
              File(p.join(tempDir.path, 'albumart_${fileName.hashCode}.png'));
          await artFile.writeAsBytes(albumArt);
          artFilePath = artFile.path;
        } catch (e) {
          // If writing fails, fallback to in-memory album art
          artFilePath = null;
        }
      }

      // Create MediaItem with complete metadata
      final mediaItem = MediaItem(
        id: '$path-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        album: album,
        artist: artist,
        artUri: artFilePath != null ? Uri.file(artFilePath) : null,
        extras: {
          'path': path,
          'offline': true,
        },
      );

      // Update current song notifier before starting playback
      GetIt.I<MediaPlayer>().currentSongNotifier.value = mediaItem;

      // Start playback
      await player.setAudioSource(AudioSource.file(path, tag: mediaItem));
      await player.play();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Music'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _refreshMusic(context),
          ),
        ],
      ),
      body: Consumer<MusicLibraryProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => _refreshMusic(context),
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.allMusicFiles.isEmpty
                    ? const Center(child: Text('No music files found.'))
                    : ListView.builder(
                        itemCount: provider.allMusicFiles.length,
                        itemBuilder: (context, index) {
                          final file = provider.allMusicFiles[index];
                          _fetchAlbumArt(file.path);
                          final albumArt = _albumArts[file.path];
                          Widget leadingWidget;
                          if (albumArt != null) {
                            final tempDir = Directory.systemTemp;
                            final artFile = File(
                                '${tempDir.path}/albumart_${file.path.hashCode}.png');
                            if (artFile.existsSync()) {
                              leadingWidget = ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  artFile,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              );
                            } else {
                              leadingWidget = ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  albumArt,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                          } else {
                            leadingWidget = const Icon(Icons.music_note);
                          }
                          return ListTile(
                            leading: leadingWidget,
                            title: Text(file.path.split('/').last),
                            onTap: () {
                              _playFile(file.path);
                            },
                          );
                        },
                      ),
          );
        },
      ),
    );
  }
}
