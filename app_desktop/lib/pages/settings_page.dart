import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_server_provider.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncServerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text('设置', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),

              // 服务控制
              _SectionTitle('服务控制'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        provider.isRunning ? Icons.play_circle : Icons.stop_circle,
                        color: provider.isRunning ? Colors.green : Colors.red,
                      ),
                      title: Text(provider.isRunning ? '服务运行中' : '服务已停止'),
                      subtitle: Text(
                        provider.isRunning
                            ? '${provider.deviceInfo.ip}:${provider.deviceInfo.port}'
                            : '点击启动',
                      ),
                      trailing: Switch(
                        value: provider.isRunning,
                        onChanged: (value) async {
                          if (value) {
                            await provider.startServer();
                          } else {
                            await provider.stopServer();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 存储设置
              _SectionTitle('存储设置'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: const Text('存储路径'),
                      subtitle: Text(provider.storageRoot),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changeStoragePath(context, provider),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('磁盘空间'),
                      subtitle: Text(
                        provider.freeDiskSpace != null
                            ? '可用: ${_formatBytes(provider.freeDiskSpace!)}'
                            : '检测中...',
                      ),
                      trailing: provider.isDiskLow
                          ? const Chip(
                              label: Text('空间不足'),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: const Text('打开存储目录'),
                      onTap: () => _openStorageDir(provider.storageRoot),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 设备信息
              _SectionTitle('设备信息'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.computer),
                      title: const Text('设备名称'),
                      subtitle: Text(provider.deviceInfo.deviceName),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: const Text('IP 地址'),
                      subtitle: Text(provider.deviceInfo.ip),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('应用版本'),
                      subtitle: Text(provider.deviceInfo.appVersion),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('已同步文件'),
                      subtitle: Text('${provider.syncedCount} 个'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 配对管理
              _SectionTitle('配对管理'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        provider.isPaired
                            ? Icons.phone_android
                            : Icons.phonelink_off,
                        color: provider.isPaired ? Colors.green : Colors.grey,
                      ),
                      title: Text(provider.isPaired ? '已配对' : '未配对'),
                      subtitle: Text(provider.pairedDeviceName ?? '暂无设备连接'),
                    ),
                    if (provider.isPaired) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.link_off, color: Colors.red),
                        title: const Text('解除配对'),
                        onTap: () => _showUnpairDialog(context, provider),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _changeStoragePath(
      BuildContext context, SyncServerProvider provider) async {
    final controller = TextEditingController(text: provider.storageRoot);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改存储路径'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '存储路径',
            hintText: '输入绝对路径',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await provider.setStorageRoot(result);
    }
  }

  void _showUnpairDialog(BuildContext context, SyncServerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解除配对'),
        content: Text('确定要解除与 ${provider.pairedDeviceName} 的配对吗？\n解除后需要重新扫码配对。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.regeneratePairingCode();
              Navigator.pop(ctx);
            },
            child: const Text('确认解除'),
          ),
        ],
      ),
    );
  }

  void _openStorageDir(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
