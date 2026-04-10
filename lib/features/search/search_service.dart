import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';

class SearchService {
  static const _fallbackHost = 'photon.komoot.io';

  Future<List<SearchResult>> search(String query, {LatLng? near}) async {
    if (query.trim().length < 2) return [];

    // Try self-hosted first, fallback to public
    var results = await _searchFrom(AppConstants.photonHost, query, near);
    if (results.isEmpty) {
      results = await _searchFrom(_fallbackHost, query, near);
    }
    return results;
  }

  // DACH bounding box (Germany, Austria, Switzerland + margins)
  static const _bboxMinLon = 5.5;
  static const _bboxMaxLon = 17.2;
  static const _bboxMinLat = 45.8;
  static const _bboxMaxLat = 55.1;

  static const _dachCountries = {
    'Deutschland', 'Germany',
    'Österreich', 'Austria',
    'Schweiz', 'Switzerland',
    'Liechtenstein',
    'Luxemburg', 'Luxembourg',
  };

  Future<List<SearchResult>> _searchFrom(String host, String query, LatLng? near) async {
    final params = {
      'q': query,
      'limit': '15', // fetch more, then filter to DACH
      'lang': 'de',
      'bbox': '$_bboxMinLon,$_bboxMinLat,$_bboxMaxLon,$_bboxMaxLat',
    };
    if (near != null) {
      params['lat'] = near.latitude.toString();
      params['lon'] = near.longitude.toString();
    }

    try {
      final uri = Uri.https(host, '/api/', params);
      final response = await http
          .get(uri, headers: {'User-Agent': 'PeakMoto/0.1'})
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = json['features'] as List;

      final results = <SearchResult>[];
      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>;
        final coords = f['geometry']['coordinates'] as List;
        final country = props['country'] as String? ?? '';

        // Only include DACH results
        if (!_dachCountries.contains(country)) continue;

        results.add(SearchResult(
          name: props['name'] as String? ?? '',
          city: props['city'] as String? ?? props['town'] as String? ?? '',
          state: props['state'] as String? ?? '',
          country: country,
          position: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
        ));
        if (results.length >= 6) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}

class SearchResult {
  final String name;
  final String city;
  final String state;
  final String country;
  final LatLng position;

  const SearchResult({
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    required this.position,
  });

  String get title => name.isNotEmpty ? name : city;

  String get subtitle {
    final parts = <String>[];
    if (city.isNotEmpty && city != name) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    return parts.join(', ');
  }
}
