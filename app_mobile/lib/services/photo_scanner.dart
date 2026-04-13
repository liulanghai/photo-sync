import 'package:photo_manager/photo_manager.dart';
import 'package:photo_sync_core/photo_sync_core.dart';

/// 手机端相册扫描服务
class PhotoScanner {
  /// 请求存储权限
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth || result.hasAccess;
  }

  /// 扫描所有相册，获取照片和视频信息
  /// [sinceTimestamp] 只获取该时间之后的文件（Unix 秒），为 0 则获取全部
  Future<List<PhotoInfo>> scanAll({int sinceTimestamp = 0}) async {
    // 获取所有相册
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // 照片 + 视频
      hasAll: false,
    );

    final result = <PhotoInfo>[];
    final seen = <String>{}; // 防止跨相册重复

    for (final album in albums) {
      final assets = await _getAlbumAssets(album, sinceTimestamp);
      for (final photo in assets) {
        if (seen.add(photo.fingerprint)) {
          result.add(photo);
        }
      }
    }

    return result;
  }

  /// 扫描指定相册
  Future<List<PhotoInfo>> scanAlbum(AssetPathEntity album,
      {int sinceTimestamp = 0}) async {
    return _getAlbumAssets(album, sinceTimestamp);
  }

  /// 获取所有相册列表
  Future<List<AlbumInfo>> getAlbumList() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: false,
    );

    final result = <AlbumInfo>[];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      result.add(AlbumInfo(
        id: album.id,
        name: album.name,
        assetCount: count,
      ));
    }
    return result;
  }

  Future<List<PhotoInfo>> _getAlbumAssets(
      AssetPathEntity album, int sinceTimestamp) async {
    final count = await album.assetCountAsync;
    if (count == 0) return [];

    // 分页加载所有资源
    final photos = <PhotoInfo>[];
    int page = 0;
    const pageSize = 100;

    while (true) {
      final assets = await album.getAssetListPaged(
        page: page,
        size: pageSize,
      );
      if (assets.isEmpty) break;

      for (final asset in assets) {
        final createTime = asset.createDateTime.millisecondsSinceEpoch ~/ 1000;
        if (sinceTimestamp > 0 && createTime <= sinceTimestamp) continue;

        final file = await asset.file;
        if (file == null) continue;

        photos.add(PhotoInfo(
          fileName: asset.title ?? 'unknown_${asset.id}',
          filePath: file.path,
          album: album.name,
          fileSize: asset.size,
          dateAdded: createTime,
          dateModified: asset.modifiedDateTime.millisecondsSinceEpoch ~/ 1000,
          width: asset.width,
          height: asset.height,
          mimeType: asset.mimeType,
        ));
      }

      if (assets.length < pageSize) break;
      page++;
    }

    return photos;
  }
}

/// 相册信息
class AlbumInfo {
  final String id;
  final String name;
  final int assetCount;

  AlbumInfo({
    required this.id,
    required this.name,
    required this.assetCount,
  });
}
