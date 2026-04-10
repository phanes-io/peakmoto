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

  Future<List<SearchResult>> _searchFrom(String host, String query, LatLng? near) async {
    final params = {
      'q': query,
      'limit': '6',
      'lang': 'de',
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

      return features.map((f) {
        final props = f['properties'] as Map<String, dynamic>;
        final coords = f['geometry']['coordinates'] as List;

        return SearchResult(
          name: props['name'] as String? ?? '',
          city: props['city'] as String? ?? props['town'] as String? ?? '',
          state: props['state'] as String? ?? '',
          country: props['country'] as String? ?? '',
          position: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
        );
      }).toList();
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
