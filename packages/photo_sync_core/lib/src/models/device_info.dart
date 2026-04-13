/// 设备信息模型
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform; // 'android', 'windows', 'macos', 'linux'
  final String appVersion;
  final String ip;
  final int port;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.ip,
    required this.port,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'appVersion': appVersion,
        'ip': ip,
        'port': port,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        platform: json['platform'] as String,
        appVersion: json['appVersion'] as String,
        ip: json['ip'] as String? ?? '',
        port: json['port'] as int? ?? 53317,
      );
}
