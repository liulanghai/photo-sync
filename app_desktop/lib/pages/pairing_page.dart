import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/sync_server_provider.dart';

/// 配对页面：展示二维码和配对码
class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncServerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设备配对', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '使用手机 App 扫描下方二维码完成配对',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),

              if (provider.isPaired) ...[
                // 已配对状态
                Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            '已与 ${provider.pairedDeviceName} 配对',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () => _showUnpairDialog(context, provider),
                            icon: const Icon(Icons.link_off),
                            label: const Text('解除配对'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (provider.pairingCode != null) ...[
                // 未配对：展示二维码
                Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // 二维码
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: provider.pairingCode!,
                              version: QrVersions.auto,
                              size: 240,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 配对码
                          Text(
                            '配对确认码',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              provider.confirmCode ?? '----',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '请确认手机端显示的确认码与上方一致',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 24),

                          // 连接信息
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${provider.deviceInfo.ip}:${provider.deviceInfo.port}',
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 刷新按钮
                          TextButton.icon(
                            onPressed: provider.regeneratePairingCode,
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新二维码'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // 服务未启动
                const Center(
                  child: Text('请先启动服务'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showUnpairDialog(BuildContext context, SyncServerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解除配对'),
        content: Text('确定要解除与 ${provider.pairedDeviceName} 的配对吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
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
}
