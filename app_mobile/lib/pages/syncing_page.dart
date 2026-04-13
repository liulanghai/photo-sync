import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';

/// 同步进度页面（全屏版，从主页点击"开始同步"后跳转）
class SyncingPage extends StatelessWidget {
  const SyncingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, provider, _) {
        final task = provider.currentTask;

        return Scaffold(
          appBar: AppBar(title: const Text('同步中')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: task == null
                ? const Center(child: Text('暂无同步任务'))
                : Column(
                    children: [
                      const SizedBox(height: 32),

                      // 进度环
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: task.progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            Center(
                              child: Text(
                                '${(task.progress * 100).toInt()}%',
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 文件计数
                      Text(
                        '${task.currentIndex} / ${task.totalFiles}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${task.transferredSizeFormatted} / ${task.totalSizeFormatted}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // 统计
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Badge('成功', '${task.successCount}', Colors.green),
                          const SizedBox(width: 16),
                          _Badge('跳过', '${task.skippedCount}', Colors.grey),
                          const SizedBox(width: 16),
                          _Badge('失败', '${task.failedCount}', Colors.red),
                        ],
                      ),

                      const Spacer(),

                      // 操作按钮
                      if (provider.isSyncing)
                        Row(
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
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  provider.cancelSync();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.stop),
                                label: const Text('取消'),
                              ),
                            ),
                          ],
                        )
                      else if (provider.isPaused)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: provider.resumeSync,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('继续同步'),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('完成'),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
