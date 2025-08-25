import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('music_library.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE music_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        lastModified INTEGER NOT NULL,
        size INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertMusicFile(File file) async {
    final db = await database;
    final stat = await file.stat();

    final data = {
      'path': file.path,
      'lastModified': stat.modified.millisecondsSinceEpoch,
      'size': stat.size,
    };

    try {
      return await db.insert(
        'music_files',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting music file: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getAllMusicFiles() async {
    final db = await database;
    return await db.query('music_files');
  }

  Future<void> clearMusicFiles() async {
    final db = await database;
    await db.delete('music_files');
  }

  Future<void> deleteMusicFile(String path) async {
    final db = await database;
    await db.delete(
      'music_files',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<bool> fileExists(String path) async {
    final db = await database;
    final result = await db.query(
      'music_files',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
