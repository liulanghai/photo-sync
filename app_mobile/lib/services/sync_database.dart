import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// 手机端本地同步数据库
class SyncDatabase {
  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'photo_sync.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fingerprint TEXT NOT NULL UNIQUE,
            file_path TEXT NOT NULL,
            album TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            date_added INTEGER NOT NULL,
            synced_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_fingerprint ON sync_records(fingerprint)',
        );
        await db.execute(
          'CREATE INDEX idx_album ON sync_records(album)',
        );
        await db.execute(
          'CREATE INDEX idx_date_added ON sync_records(date_added)',
        );
      },
    );
  }

  /// 获取所有已同步的 fingerprint
  Future<List<String>> getAllFingerprints() async {
    final db = await database;
    final result = await db.query('sync_records', columns: ['fingerprint']);
    return result.map((r) => r['fingerprint'] as String).toList();
  }

  /// 检查指纹是否已同步
  Future<bool> isSynced(String fingerprint) async {
    final db = await database;
    final result = await db.query(
      'sync_records',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 记录同步成功
  Future<void> markSynced({
    required String fingerprint,
    required String filePath,
    required String album,
    required int fileSize,
    required int dateAdded,
  }) async {
    final db = await database;
    await db.insert(
      'sync_records',
      {
        'fingerprint': fingerprint,
        'file_path': filePath,
        'album': album,
        'file_size': fileSize,
        'date_added': dateAdded,
        'synced_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 获取同步记录总数
  Future<int> getSyncedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sync_records');
    return result.first['cnt'] as int;
  }

  /// 获取所有已同步的相册
  Future<List<String>> getSyncedAlbums() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT album FROM sync_records ORDER BY album',
    );
    return result.map((r) => r['album'] as String).toList();
  }

  // ======== 重置功能 ========

  /// 完全清空所有同步记录
  Future<int> clearAll() async {
    final db = await database;
    return await db.delete('sync_records');
  }

  /// 清除指定时间之后的同步记录
  Future<int> clearSince(int dateAddedTimestamp) async {
    final db = await database;
    return await db.delete(
      'sync_records',
      where: 'date_added >= ?',
      whereArgs: [dateAddedTimestamp],
    );
  }

  /// 清除指定相册的同步记录
  Future<int> clearAlbum(String album) async {
    final db = await database;
    return await db.delete(
      'sync_records',
      where: 'album = ?',
      whereArgs: [album],
    );
  }

  /// 清除多个相册的同步记录
  Future<int> clearAlbums(List<String> albums) async {
    final db = await database;
    final placeholders = albums.map((_) => '?').join(',');
    return await db.delete(
      'sync_records',
      where: 'album IN ($placeholders)',
      whereArgs: albums,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
