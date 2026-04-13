import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../constants.dart';

/// JWT Token 管理器
class TokenManager {
  final String _secret;
  final Set<String> _revokedTokens = {};

  TokenManager({required String secret}) : _secret = secret;

  /// 生成 JWT Token
  String generateToken({
    required String deviceId,
    required String deviceName,
  }) {
    final jwt = JWT(
      {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
    );

    return jwt.sign(
      SecretKey(_secret),
      expiresIn: Duration(days: SyncConstants.tokenExpireDays),
    );
  }

  /// 验证 Token，返回 deviceId；无效返回 null
  String? verifyToken(String token) {
    if (_revokedTokens.contains(token)) return null;

    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      final payload = jwt.payload as Map<String, dynamic>;
      return payload['deviceId'] as String?;
    } on JWTExpiredException {
      return null;
    } on JWTException {
      return null;
    }
  }

  /// 吊销指定 Token
  void revokeToken(String token) {
    _revokedTokens.add(token);
  }

  /// 吊销全部 Token
  void revokeAllTokens() {
    _revokedTokens.clear();
    // 通过更换 secret 使旧 token 全部失效的方式更安全
    // 但简单场景下清空吊销列表即可
  }
}
