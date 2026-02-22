import 'dart:io';

import 'package:http/http.dart' show ClientException;

/// ネットワーク／DNS不調（host lookup 失敗など）かどうかを判定する。
bool isNetworkDnsError(Object e) {
  if (e is SocketException) return true;
  if (e is ClientException) {
    final m = e.message.toLowerCase();
    return m.contains('host lookup') ||
        m.contains('nodename nor servname') ||
        m.contains('failed host lookup');
  }
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') &&
      (s.contains('host lookup') || s.contains('nodename nor servname'))) {
    return true;
  }
  if (s.contains('clientexception') &&
      (s.contains('host lookup') || s.contains('nodename nor servname'))) {
    return true;
  }
  return false;
}

/// ユーザーに表示するエラーメッセージに変換する。
/// ネットワーク／DNSエラーの場合は案内文を返し、それ以外は [e] の文字列から "Exception: " を除いて返す。
String userFacingErrorMessage(Object e) {
  if (isNetworkDnsError(e)) {
    return '接続できません。Wi‑Fi／モバイルデータを確認するか、しばらくして再試行してください。';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
