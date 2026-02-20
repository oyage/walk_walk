import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../domain/models/geo_point.dart';
import '../../../domain/services/geocoding_provider.dart';

/// Google Geocoding API実装
class GoogleGeocodingProvider implements GeocodingProvider {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  String? get _apiKey => dotenv.env['GOOGLE_GEOCODING_API_KEY'] ??
      dotenv.env['GOOGLE_PLACES_API_KEY'];

  @override
  Future<String?> reverseGeocode(GeoPoint point) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Geocoding API key is not configured');
    }

    final url = Uri.parse(
      '$_baseUrl?latlng=${point.lat},${point.lng}&key=$_apiKey&language=ja',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            // 最初の結果から住所を取得
            final result = results[0];
            final formattedAddress = result['formatted_address'] as String?;
            if (formattedAddress != null) {
              // 簡易的に地域名を抽出（例: "東京都渋谷区..." → "渋谷区"）
              return _extractAreaName(formattedAddress);
            }

            // formatted_addressがない場合は、address_componentsから取得
            final addressComponents = result['address_components'] as List?;
            if (addressComponents != null) {
              return _extractAreaNameFromComponents(addressComponents);
            }
          }
        } else if (data['status'] == 'ZERO_RESULTS') {
          return null;
        }
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded');
      }
      return null;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Geocoding failed: $e');
    }
  }

  /// フォーマット済み住所から地域名を抽出
  String _extractAreaName(String formattedAddress) {
    // 日本の住所形式: "都道府県市区町村..."
    // 例: "東京都渋谷区神南1-1-1" → "渋谷区"
    final parts = formattedAddress.split(RegExp(r'[都道府県市区町村]'));
    if (parts.length >= 2) {
      // 都道府県名 + 市区町村名を返す
      final prefecture = formattedAddress.substring(0, parts[0].length + 1);
      if (parts.length >= 3) {
        final city = parts[1] + formattedAddress[parts[0].length + 1];
        return prefecture + city;
      }
      return prefecture;
    }
    return formattedAddress;
  }

  /// address_componentsから地域名を抽出
  String _extractAreaNameFromComponents(List addressComponents) {
    String? prefecture;
    String? city;

    for (final component in addressComponents) {
      final types = component['types'] as List?;
      if (types == null) continue;

      if (types.contains('administrative_area_level_1')) {
        prefecture = component['long_name'] as String?;
      } else if (types.contains('administrative_area_level_2') ||
          types.contains('locality')) {
        city = component['long_name'] as String?;
      }
    }

    if (prefecture != null && city != null) {
      return '$prefecture$city';
    } else if (prefecture != null) {
      return prefecture;
    } else if (city != null) {
      return city;
    }

    return '不明な地域';
  }
}
