import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../domain/models/geo_point.dart';
import '../../../domain/models/poi_candidate.dart';
import '../../../domain/services/places_provider.dart';

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
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List?;
          if (results != null) {
            return results.map((r) => _parsePlaceResult(r, point)).toList();
          }
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        }
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded');
      }
      return [];
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
    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        _toRadians(lat1).cos() *
            _toRadians(lat2).cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();
    final c = 2 * (a.sqrt()).asin();
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);
}
