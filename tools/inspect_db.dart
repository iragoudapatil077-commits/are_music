import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase('.dart_tool/sqflite_common_ffi/databases/music_library.db');
  final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
  print('tables: $tables');
  try {
    final rows = await db.query('music_files');
    print('rows count: ${rows.length}');
    for (var r in rows) {
      print(r);
    }
  } catch (e) {
    print('error reading music_files: $e');
  }
  await db.close();
}
