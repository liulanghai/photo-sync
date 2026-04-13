import 'dart:convert';

/// 配对信息模型（编码到二维码中）
class PairingInfo {
  final String ip;
  final int port;
  final String pairingCode;
  final String deviceName;
  final String deviceId;

  PairingInfo({
    required this.ip,
    required this.port,
    required this.pairingCode,
    required this.deviceName,
    required this.deviceId,
  });

  /// 确认码（配对码后 4 位）
  String get confirmCode => pairingCode.substring(pairingCode.length - 4);

  /// 编码为二维码字符串
  String toQrString() => jsonEncode(toJson());

  /// 从二维码字符串解码
  factory PairingInfo.fromQrString(String qrString) {
    final json = jsonDecode(qrString) as Map<String, dynamic>;
    return PairingInfo.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'port': port,
        'pairingCode': pairingCode,
        'deviceName': deviceName,
        'deviceId': deviceId,
        'protocol': 'photosync',
        'version': 1,
      };

  factory PairingInfo.fromJson(Map<String, dynamic> json) => PairingInfo(
        ip: json['ip'] as String,
        port: json['port'] as int,
        pairingCode: json['pairingCode'] as String,
        deviceName: json['deviceName'] as String,
        deviceId: json['deviceId'] as String,
      );
}
