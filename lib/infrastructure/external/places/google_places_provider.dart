import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../domain/models/geo_point.dart';
import '../../../domain/models/poi_candidate.dart';
import '../../../domain/services/places_provider.dart';
import '../../logging/app_logger.dart';

/// Google Places API実装
class GooglePlacesProvider implements PlacesProvider {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  String? get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'];

  @override
  Future<List<PoiCandidate>> searchNearby({
    required GeoPoint point,
    required int radiusMeters,
    List<String>? categories,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is not configured');
    }

    // カテゴリをtypeパラメータに変換（簡易実装）
    final type = categories?.isNotEmpty == true ? categories!.first : 'point_of_interest';

    final url = Uri.parse(
      '$_baseUrl?location=${point.lat},${point.lng}&radius=$radiusMeters&type=$type&key=$_apiKey&language=ja',
    );

    try {
      if (kDebugMode) {
        AppLogger.d('Places API GET ${_sanitizedUrl(url)}');
      }
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        final errorMessage = data['error_message'] as String? ?? '';

        if (status == 'OK') {
          final results = data['results'] as List?;
          if (kDebugMode) {
            final count = results?.length ?? 0;
            AppLogger.d('Places API response type=$type statusCode=${response.statusCode} results=$count');
          }
          if (results != null) {
            return results.map((r) => _parsePlaceResult(r, point)).toList();
          }
          return [];
        }
        if (status == 'ZERO_RESULTS') {
          if (kDebugMode) {
            AppLogger.d('Places API response type=$type statusCode=${response.statusCode} results=0');
          }
          return [];
        }

        // REQUEST_DENIED / INVALID_REQUEST / OVER_QUERY_LIMIT 等はログ出力して例外
        AppLogger.w('Places API error: type=$type status=$status error_message=$errorMessage');
        throw Exception(
          'Places API failed: status=$status${errorMessage.isNotEmpty ? ' message=$errorMessage' : ''}',
        );
      }
      if (kDebugMode && response.statusCode != 200) {
        AppLogger.d('Places API response statusCode=${response.statusCode}');
      }
      if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded');
      }
      throw Exception('Places API HTTP error: statusCode=${response.statusCode}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Places search failed: $e');
    }
  }

  PoiCandidate _parsePlaceResult(Map<String, dynamic> result, GeoPoint origin) {
    final name = result['name'] as String? ?? '';
    final types = result['types'] as List?;
    final category = _extractCategory(types);
    
    // 距離計算（簡易版、実際はgeometry.locationから計算）
    int? distanceMeters;
    if (result['geometry'] != null && result['geometry']['location'] != null) {
      final loc = result['geometry']['location'];
      final lat = loc['lat'] as double?;
      final lng = loc['lng'] as double?;
      if (lat != null && lng != null) {
        distanceMeters = _calculateDistance(
          origin.lat,
          origin.lng,
          lat,
          lng,
        ).round();
      }
    }

    return PoiCandidate(
      name: name,
      category: category,
      distanceMeters: distanceMeters,
      sourceId: result['place_id'] as String?,
    );
  }

  String _extractCategory(List? types) {
    if (types == null || types.isEmpty) return 'point_of_interest';
    
    // 優先順位: park > cafe > restaurant > station > ...
    final priority = ['park', 'cafe', 'restaurant', 'train_station', 'convenience_store'];
    for (final p in priority) {
      if (types.contains(p)) return p;
    }
    return types.first as String;
  }

  /// 2点間の距離を計算（Haversine formula）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);

  static String _sanitizedUrl(Uri u) {
    return u.toString().replaceAll(RegExp(r'key=[^&]+'), 'key=***');
  }
}
