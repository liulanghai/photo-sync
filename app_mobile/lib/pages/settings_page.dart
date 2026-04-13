import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';

/// 手机端设置页面（含同步重置功能）
class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 连接信息
              _SectionHeader('连接信息'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        provider.isConnected ? Icons.wifi : Icons.wifi_off,
                        color: provider.isConnected ? Colors.green : Colors.red,
                      ),
                      title: Text(provider.isConnected ? '已连接' : '未连接'),
                      subtitle: Text(provider.serverIp ?? '暂无'),
                    ),
                    if (provider.isConnected) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.computer),
                        title: const Text('电脑名称'),
                        subtitle: Text(provider.serverDeviceName ?? '未知'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.link_off, color: Colors.red),
                        title: const Text('断开连接'),
                        onTap: () => provider.disconnect(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 同步统计
              _SectionHeader('同步统计'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_done),
                  title: const Text('已同步文件'),
                  subtitle: Text('${provider.syncedCount} 个'),
                ),
              ),
              const SizedBox(height: 16),

              // 同步重置
              _SectionHeader('同步重置'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Colors.orange),
                      title: const Text('完全重新同步'),
                      subtitle: const Text('清空所有同步记录，下次全量重新同步'),
                      onTap: () => _confirmResetAll(context, provider),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.date_range, color: Colors.orange),
                      title: const Text('从指定日期重新同步'),
                      subtitle: const Text('该日期之后的照片将重新同步'),
                      onTap: () => _pickDateAndReset(context, provider),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.folder, color: Colors.orange),
                      title: const Text('重新同步指定相册'),
                      subtitle: const Text('选择需要重新同步的相册'),
                      onTap: () => _pickAlbumsAndReset(context, provider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 关于
              _SectionHeader('关于'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('PhotoSync'),
                      subtitle: Text('版本 1.0.0'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.description),
                      title: Text('说明'),
                      subtitle: Text('通过局域网将手机照片和视频同步到电脑'),
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

  void _confirmResetAll(BuildContext context, SyncProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完全重新同步'),
        content: const Text(
          '确定要清空所有同步记录吗？\n\n'
          '清空后，下次打开同步将重新传输所有照片和视频。\n'
          '（不会删除电脑上已有的文件）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清空全部同步记录')),
                );
              }
            },
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  void _pickDateAndReset(BuildContext context, SyncProvider provider) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: '选择重新同步的起始日期',
    );

    if (picked != null && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认重置'),
          content: Text(
            '将清除 ${picked.toString().substring(0, 10)} 之后的同步记录。\n\n'
            '这些照片/视频将在下次同步时重新传输。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await provider.resetSince(picked);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已清除 ${picked.toString().substring(0, 10)} 之后的记录')),
          );
        }
      }
    }
  }

  void _pickAlbumsAndReset(BuildContext context, SyncProvider provider) async {
    // 获取已同步的相册列表
    final albums = await provider.database.getSyncedAlbums();
    if (albums.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无已同步的相册')),
        );
      }
      return;
    }

    final selected = <String>{};

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('选择要重新同步的相册'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albums.length,
              itemBuilder: (_, index) {
                final album = albums[index];
                return CheckboxListTile(
                  value: selected.contains(album),
                  title: Text(album),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(album);
                      } else {
                        selected.remove(album);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('确认重置'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selected.isNotEmpty) {
      await provider.resetAlbums(selected.toList());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 ${selected.join(", ")} 的同步记录')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
