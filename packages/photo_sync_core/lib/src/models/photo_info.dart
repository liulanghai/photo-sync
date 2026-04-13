/// 照片/视频文件信息模型
class PhotoInfo {
  final String fileName;
  final String filePath;
  final String album;
  final int fileSize;
  final int dateAdded;
  final int dateModified;
  final int? width;
  final int? height;
  final String? mimeType;

  PhotoInfo({
    required this.fileName,
    required this.filePath,
    required this.album,
    required this.fileSize,
    required this.dateAdded,
    required this.dateModified,
    this.width,
    this.height,
    this.mimeType,
  });

  /// 生成快速指纹：相册/文件名|文件大小|创建时间
  String get fingerprint => '$album/$fileName|$fileSize|$dateAdded';

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'filePath': filePath,
        'album': album,
        'fileSize': fileSize,
        'dateAdded': dateAdded,
        'dateModified': dateModified,
        'width': width,
        'height': height,
        'mimeType': mimeType,
        'fingerprint': fingerprint,
      };

  factory PhotoInfo.fromJson(Map<String, dynamic> json) => PhotoInfo(
        fileName: json['fileName'] as String,
        filePath: json['filePath'] as String? ?? '',
        album: json['album'] as String,
        fileSize: json['fileSize'] as int,
        dateAdded: json['dateAdded'] as int,
        dateModified: json['dateModified'] as int? ?? 0,
        width: json['width'] as int?,
        height: json['height'] as int?,
        mimeType: json['mimeType'] as String?,
      );
}
