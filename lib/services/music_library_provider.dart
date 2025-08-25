import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';

class MusicLibraryProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<File> _allMusicFiles = [];
  bool _loading = false;

  List<File> get allMusicFiles => _allMusicFiles;
  bool get loading => _loading;

  // Initialize by loading saved files
  Future<void> init() async {
    await loadSavedFiles();
  }

  // Load music files from database
  Future<void> loadSavedFiles() async {
    _loading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> files = await _db.getAllMusicFiles();
      _allMusicFiles = files
          .map((data) => File(data['path']))
          .where((file) => file.existsSync())
          .toList();

      // Remove entries for files that no longer exist
      for (var file in files.where((f) => !File(f['path']).existsSync())) {
        await _db.deleteMusicFile(file['path']);
      }
    } catch (e) {
      print('Error loading saved files: $e');
      _allMusicFiles = [];
    }

    _loading = false;
    notifyListeners();
  }

  // Scan for new music files and update database
  Future<void> scanAllMusicFiles(Future<List<File>> Function() scanFunc) async {
    _loading = true;
    notifyListeners();

    try {
      // Clear existing records if this is a full rescan
      await _db.clearMusicFiles();

      // Scan for music files
      final List<File> newFiles = await scanFunc();

      // Add all files to database
      for (var file in newFiles) {
        await _db.insertMusicFile(file);
      }

      _allMusicFiles = newFiles;
    } catch (e) {
      print('Error scanning music files: $e');
      _allMusicFiles = [];
    }

    _loading = false;
    notifyListeners();
  }
}
