import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_server_provider.dart';
import 'pairing_page.dart';
import 'browser_page.dart';
import 'settings_page.dart';

/// 电脑端主页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.sync, size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('PhotoSync', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('状态'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: Text('浏览'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.qr_code_outlined),
                selectedIcon: Icon(Icons.qr_code),
                label: Text('配对'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 主内容区
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                StatusPanel(),
                BrowserPage(),
                PairingPage(),
                SettingsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态面板
class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncServerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text('同步状态', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),

              // 状态卡片
              Row(
                children: [
                  _StatusCard(
                    icon: provider.isRunning ? Icons.cloud_done : Icons.cloud_off,
                    color: provider.isRunning ? Colors.green : Colors.red,
                    title: '服务状态',
                    value: provider.isRunning ? '运行中' : '已停止',
                    subtitle: provider.isRunning
                        ? 'http://${provider.deviceInfo.ip}:${provider.deviceInfo.port}'
                        : '点击启动',
                  ),
                  const SizedBox(width: 16),
                  _StatusCard(
                    icon: provider.isPaired ? Icons.phone_android : Icons.phonelink_off,
                    color: provider.isPaired ? Colors.green : Colors.orange,
                    title: '设备连接',
                    value: provider.isPaired ? '已配对' : '未配对',
                    subtitle: provider.pairedDeviceName ?? '等待手机连接',
                  ),
                  const SizedBox(width: 16),
                  _StatusCard(
                    icon: Icons.photo_library,
                    color: Colors.blue,
                    title: '已同步文件',
                    value: '${provider.syncedCount}',
                    subtitle: provider.storageRoot,
                  ),
                  const SizedBox(width: 16),
                  _StatusCard(
                    icon: Icons.storage,
                    color: provider.isDiskLow ? Colors.red : Colors.green,
                    title: '磁盘空间',
                    value: provider.freeDiskSpace != null
                        ? _formatBytes(provider.freeDiskSpace!)
                        : '检测中...',
                    subtitle: provider.isDiskLow ? '⚠️ 空间不足' : '正常',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 同步进度（如果正在同步）
              if (provider.isSyncing) ...[ 
                _SyncProgressCard(provider: provider),
                const SizedBox(height: 24),
              ],

              // 日志
              Text('运行日志', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.logs.length,
                    itemBuilder: (context, index) {
                      final logIndex = provider.logs.length - 1 - index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          provider.logs[logIndex],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 同步进度卡片 — 显示详细的传输进度
class _SyncProgressCard extends StatelessWidget {
  final SyncServerProvider provider;

  const _SyncProgressCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFileProgress = provider.currentFileTotalBytes > 0;
    final fileProgress = provider.currentFileProgress;
    final speed = provider.transferSpeed;

    // 估算剩余时间
    String etaText = '';
    if (hasFileProgress && speed > 0) {
      final remainingBytes = provider.currentFileTotalBytes - provider.currentFileReceivedBytes;
      final etaSeconds = (remainingBytes / speed).round();
      if (etaSeconds < 60) {
        etaText = '约 ${etaSeconds}s';
      } else if (etaSeconds < 3600) {
        etaText = '约 ${etaSeconds ~/ 60}m ${etaSeconds % 60}s';
      } else {
        etaText = '约 ${etaSeconds ~/ 3600}h ${(etaSeconds % 3600) ~/ 60}m';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '正在接收: ${provider.currentFileName ?? ""}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 当前文件进度条（确定进度）
            if (hasFileProgress) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fileProgress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 已传输 / 总大小
                  Text(
                    '${_formatBytes(provider.currentFileReceivedBytes)} / ${_formatBytes(provider.currentFileTotalBytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // 百分比
                  Text(
                    '${(fileProgress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 传输速度
                  if (speed > 0)
                    Text(
                      '${_formatBytes(speed.round())}/s',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue,
                          ),
                    )
                  else
                    const SizedBox.shrink(),
                  // 预计剩余时间
                  if (etaText.isNotEmpty)
                    Text(
                      etaText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                ],
              ),
            ] else ...[
              // 无法确定大小时显示不确定进度
              const LinearProgressIndicator(),
            ],

            // 总体文件数进度
            if (provider.totalFiles > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '总进度: ${provider.currentFileIndex} / ${provider.totalFiles} 个文件',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${provider.totalFiles > 0 ? (provider.currentFileIndex / provider.totalFiles * 100).toStringAsFixed(0) : 0}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: provider.totalFiles > 0
                      ? provider.currentFileIndex / provider.totalFiles
                      : 0,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 状态卡片组件
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
