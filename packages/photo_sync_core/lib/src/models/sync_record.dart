/// 本地同步记录模型（手机端数据库）
class SyncRecord {
  final int? id;
  final String fingerprint;
  final String filePath;
  final String album;
  final int fileSize;
  final int dateAdded;
  final int syncedAt;

  SyncRecord({
    this.id,
    required this.fingerprint,
    required this.filePath,
    required this.album,
    required this.fileSize,
    required this.dateAdded,
    required this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fingerprint': fingerprint,
        'filePath': filePath,
        'album': album,
        'fileSize': fileSize,
        'dateAdded': dateAdded,
        'syncedAt': syncedAt,
      };

  factory SyncRecord.fromMap(Map<String, dynamic> map) => SyncRecord(
        id: map['id'] as int?,
        fingerprint: map['fingerprint'] as String,
        filePath: map['filePath'] as String,
        album: map['album'] as String,
        fileSize: map['fileSize'] as int,
        dateAdded: map['dateAdded'] as int,
        syncedAt: map['syncedAt'] as int,
      );

  factory SyncRecord.fromPhotoInfo(PhotoInfo photo) => SyncRecord(
        fingerprint: photo.fingerprint,
        filePath: photo.filePath,
        album: photo.album,
        fileSize: photo.fileSize,
        dateAdded: photo.dateAdded,
        syncedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
}

// 需要导入 PhotoInfo
import 'photo_info.dart';
