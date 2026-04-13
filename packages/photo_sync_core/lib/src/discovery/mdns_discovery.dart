import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import '../constants.dart';
import '../models/device_info.dart';

/// mDNS 设备发现
class MdnsDiscovery {
  MDnsClient? _client;
  bool _isSearching = false;

  /// 发现设备的回调
  void Function(DeviceInfo device)? onDeviceFound;

  /// 搜索局域网内的电脑端服务
  Future<List<DeviceInfo>> search({Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <DeviceInfo>[];

    _client = MDnsClient();
    await _client!.start();
    _isSearching = true;

    try {
      await for (final PtrResourceRecord ptr in _client!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(
              '${SyncConstants.mdnsServiceType}.local',
            ),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ip
              in _client!.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            final device = DeviceInfo(
              deviceId: ptr.domainName,
              deviceName: ptr.domainName.split('.').first,
              platform: 'unknown',
              appVersion: SyncConstants.appVersion,
              ip: ip.address.address,
              port: srv.port,
            );
            devices.add(device);
            onDeviceFound?.call(device);
          }
        }
      }
    } on TimeoutException {
      // 超时正常结束
    } catch (e) {
      // 搜索异常
    } finally {
      _isSearching = false;
      _client?.stop();
      _client = null;
    }

    return devices;
  }

  /// 停止搜索
  void stop() {
    _isSearching = false;
    _client?.stop();
    _client = null;
  }

  bool get isSearching => _isSearching;
}
