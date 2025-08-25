import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileScanner {
  static Future<List<File>> scanAllMusicFiles() async {
    List<File> musicFiles = [];
    final extensions = ['.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a'];

    try {
      final List<String> foldersToScan = [];

      if (Platform.isAndroid) {
        final List<Directory>? externalDirs =
            await getExternalStorageDirectories();
        // Keep common Android locations first
        foldersToScan.addAll([
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Audio',
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/YMusic',
          '/storage/emulated/0/',
          '/sdcard/',
          '/storage/',
        ]);
        if (externalDirs != null) {
          for (var dir in externalDirs) {
            String path = dir.path;
            List<String> parts = path.split('/Android/');
            if (parts.isNotEmpty) {
              foldersToScan.add(parts[0]);
            }
          }
        }
      } else {
        // Desktop / other platforms: use common user folders
        final downloads = await getDownloadsDirectory();
        if (downloads != null) foldersToScan.add(downloads.path);

        final docs = await getApplicationDocumentsDirectory();
        foldersToScan.add(docs.path);

        // Try typical Music folder on desktop platforms
        if (Platform.isWindows) {
          final musicFolder =
              Directory('${Platform.environment['USERPROFILE']}\\Music');
          if (await musicFolder.exists()) foldersToScan.add(musicFolder.path);
        } else if (Platform.isMacOS || Platform.isLinux) {
          final musicFolder =
              Directory('${Platform.environment['HOME']}/Music');
          if (await musicFolder.exists()) foldersToScan.add(musicFolder.path);
        }
      }

      // Debug output
      // print("Starting to scan folders: $foldersToScan");

      for (final folderPath in foldersToScan) {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          try {
            await for (var entity
                in dir.list(recursive: true, followLinks: false)) {
              if (entity is File &&
                  extensions.contains(p.extension(entity.path).toLowerCase())) {
                musicFiles.add(entity);
              }
            }
          } catch (e) {
            // ignore scanning errors for inaccessible folders
          }
        }
      }

      return musicFiles;
    } catch (e) {
      return [];
    }
  }
}
