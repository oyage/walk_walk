import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:walk_walk/application/utils/network_error_util.dart';

void main() {
  group('isNetworkDnsError', () {
    test('SocketException の場合は true', () {
      const e = SocketException('Failed host lookup: example.com');
      expect(isNetworkDnsError(e), isTrue);
    });

    test('ClientException で host lookup を含む場合は true', () {
      final e = ClientException(
        'Failed host lookup: \'maps.googleapis.com\' '
        '(OS Error: nodename nor servname provided, or not known, errno = 8)',
      );
      expect(isNetworkDnsError(e), isTrue);
    });

    test('ClientException で nodename nor servname を含む場合は true', () {
      final e = ClientException(
        'Something with nodename nor servname provided',
      );
      expect(isNetworkDnsError(e), isTrue);
    });

    test('toString に SocketException と host lookup を含む場合は true', () {
      final e = _ExceptionWithMessage(
        'SocketException: Failed host lookup: example.com',
      );
      expect(isNetworkDnsError(e), isTrue);
    });

    test('通常の Exception の場合は false', () {
      expect(isNetworkDnsError(Exception('other')), isFalse);
    });

    test('ClientException で host lookup を含まない場合は false', () {
      final e = ClientException('Connection refused');
      expect(isNetworkDnsError(e), isFalse);
    });
  });

  group('userFacingErrorMessage', () {
    test('ネットワークエラー時は案内文を返す', () {
      final e = ClientException(
        'Failed host lookup: \'maps.googleapis.com\'',
      );
      expect(
        userFacingErrorMessage(e),
        '接続できません。Wi‑Fi／モバイルデータを確認するか、しばらくして再試行してください。',
      );
    });

    test('それ以外の Exception は "Exception: " を除いた文字列を返す', () {
      final e = Exception('位置情報の権限が必要です');
      expect(
        userFacingErrorMessage(e),
        '位置情報の権限が必要です',
      );
    });

    test('Exception で始まらない文字列はそのまま返す', () {
      final e = Exception('Error: something');
      expect(userFacingErrorMessage(e), isNot(contains('Exception: ')));
    });
  });
}

class _ExceptionWithMessage implements Exception {
  _ExceptionWithMessage(this.message);
  final String message;
  @override
  String toString() => message;
}
