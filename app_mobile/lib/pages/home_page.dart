import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import 'scanner_page.dart';
import 'syncing_page.dart';
import 'settings_page.dart';

/// 手机端主页
class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PhotoSync'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MobileSettingsPage()),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 连接状态卡片
                _ConnectionCard(provider: provider),
                const SizedBox(height: 16),

                // 同步统计
                _StatsCard(provider: provider),
                const SizedBox(height: 16),

                // 同步进度（如果正在同步）
                if (provider.isSyncing || provider.isPaused)
                  _SyncProgressCard(provider: provider),

                const Spacer(),

                // 操作按钮
                _ActionButtons(provider: provider),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 连接状态卡片
class _ConnectionCard extends StatelessWidget {
  final SyncProvider provider;
  const _ConnectionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isConnected = provider.isConnected;
    return Card(
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.wifi : Icons.wifi_off,
          color: isConnected ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(
          isConnected ? '已连接' : '未连接',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(provider.statusMessage),
        trailing: isConnected
            ? Chip(
                avatar: const Icon(Icons.computer, size: 16),
                label: Text(provider.serverDeviceName ?? ''),
              )
            : FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerPage()),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫码连接'),
              ),
      ),
    );
  }
}

/// 同步统计卡片
class _StatsCard extends StatelessWidget {
  final SyncProvider provider;
  const _StatsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.photo_library,
              label: '手机文件',
              value: '${provider.localFileCount}',
            ),
            _StatItem(
              icon: Icons.cloud_done,
              label: '已同步',
              value: '${provider.syncedCount}',
            ),
            _StatItem(
              icon: Icons.cloud_upload,
              label: '待同步',
              value: '${provider.pendingFiles.length}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 同步进度卡片
class _SyncProgressCard extends StatelessWidget {
  final SyncProvider provider;
  const _SyncProgressCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final task = provider.currentTask;
    if (task == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (provider.isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.pause_circle, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  provider.isSyncing ? '正在同步...' : '已暂停',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${task.currentIndex} / ${task.totalFiles}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 4),
            Text(
              '${task.transferredSizeFormatted} / ${task.totalSizeFormatted}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (task.failedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '失败: ${task.failedCount} 个文件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 操作按钮
class _ActionButtons extends StatelessWidget {
  final SyncProvider provider;
  const _ActionButtons({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isSyncing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: provider.pauseSync,
              icon: const Icon(Icons.pause),
              label: const Text('暂停'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: provider.cancelSync,
              icon: const Icon(Icons.stop),
              label: const Text('取消'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ],
      );
    }

    if (provider.isPaused) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: provider.resumeSync,
              icon: const Icon(Icons.play_arrow),
              label: const Text('继续同步'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: provider.cancelSync,
              icon: const Icon(Icons.stop),
              label: const Text('取消'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: provider.isConnected ? provider.startSync : null,
        icon: const Icon(Icons.sync),
        label: Text(
          provider.isConnected ? '开始同步' : '请先连接电脑',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
