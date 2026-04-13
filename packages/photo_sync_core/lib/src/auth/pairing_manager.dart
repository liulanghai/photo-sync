import 'dart:math';
import '../constants.dart';
import '../models/pairing_info.dart';
import 'token_manager.dart';

/// 配对管理器
class PairingManager {
  final TokenManager _tokenManager;
  String? _currentPairingCode;
  String? _pairedDeviceId;
  bool _isPaired = false;

  PairingManager({required TokenManager tokenManager})
      : _tokenManager = tokenManager;

  /// 是否已配对
  bool get isPaired => _isPaired;

  /// 已配对的设备 ID
  String? get pairedDeviceId => _pairedDeviceId;

  /// 当前配对码
  String? get currentPairingCode => _currentPairingCode;

  /// 确认码（配对码后 4 位）
  String? get confirmCode => _currentPairingCode?.substring(
      _currentPairingCode!.length - SyncConstants.confirmCodeLength);

  /// 生成新的配对码（电脑端调用）
  String generatePairingCode() {
    final random = Random.secure();
    _currentPairingCode = List.generate(
      SyncConstants.pairingCodeLength,
      (_) => random.nextInt(10),
    ).join();
    return _currentPairingCode!;
  }

  /// 生成配对信息（电脑端，用于二维码展示）
  PairingInfo generatePairingInfo({
    required String ip,
    required int port,
    required String deviceName,
    required String deviceId,
  }) {
    final code = generatePairingCode();
    return PairingInfo(
      ip: ip,
      port: port,
      pairingCode: code,
      deviceName: deviceName,
      deviceId: deviceId,
    );
  }

  /// 验证配对请求（电脑端调用）
  /// 返回 JWT Token，验证失败返回 null
  String? verifyPairingRequest({
    required String pairingCode,
    required String remoteDeviceId,
    required String remoteDeviceName,
  }) {
    if (_currentPairingCode == null) return null;
    if (pairingCode != _currentPairingCode) return null;

    // 配对成功
    _isPaired = true;
    _pairedDeviceId = remoteDeviceId;
    _currentPairingCode = null; // 配对码一次性，用完作废

    // 生成 Token
    return _tokenManager.generateToken(
      deviceId: remoteDeviceId,
      deviceName: remoteDeviceName,
    );
  }

  /// 解除配对
  void unpair() {
    _isPaired = false;
    _pairedDeviceId = null;
    _currentPairingCode = null;
    _tokenManager.revokeAllTokens();
  }
}
