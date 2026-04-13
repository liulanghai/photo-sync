import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../providers/sync_server_provider.dart';

/// 照片/视频浏览页面
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  String? _selectedAlbum;

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncServerProvider>(
      builder: (context, provider, _) {
        final albums = provider.getSyncedAlbums();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('照片浏览', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '已同步 ${provider.syncedCount} 个文件到 ${provider.storageRoot}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),

              if (albums.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无同步的照片', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('连接手机并同步后，照片将显示在这里',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      // 左侧相册列表
                      SizedBox(
                        width: 200,
                        child: Card(
                          child: ListView.builder(
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              final isSelected = album == _selectedAlbum;
                              final fileCount =
                                  provider.getAlbumFiles(album).length;
                              return ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(album),
                                subtitle: Text('$fileCount 个文件'),
                                selected: isSelected,
                                onTap: () {
                                  setState(() => _selectedAlbum = album);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 右侧文件网格
                      Expanded(
                        child: _selectedAlbum == null
                            ? const Center(child: Text('请选择一个相册'))
                            : _buildFileGrid(provider, _selectedAlbum!),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileGrid(SyncServerProvider provider, String album) {
    final files = provider.getAlbumFiles(album);
    if (files.isEmpty) {
      return const Center(child: Text('该相册为空'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = p.basename(file.path);
        final ext = p.extension(file.path).toLowerCase();
        final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif']
            .contains(ext);
        final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.3gp'].contains(ext);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openFile(file.path),
            onSecondaryTap: () => _showFileMenu(context, file.path),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: isImage
                      ? Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _FileIcon(Icons.broken_image),
                        )
                      : isVideo
                          ? const _FileIcon(Icons.videocam)
                          : const _FileIcon(Icons.insert_drive_file),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFile(String path) {
    // 调用系统默认应用打开
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  void _showFileMenu(BuildContext context, String filePath) {
    showMenu(
      context: context,
      position: RelativeRect.fill,
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('打开'),
            dense: true,
          ),
          onTap: () => _openFile(filePath),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('在文件管理器中显示'),
            dense: true,
          ),
          onTap: () => _revealInExplorer(filePath),
        ),
      ],
    );
  }

  void _revealInExplorer(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [p.dirname(path)]);
    }
  }
}

class _FileIcon extends StatelessWidget {
  final IconData icon;
  const _FileIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, size: 48, color: Colors.grey),
    );
  }
}
