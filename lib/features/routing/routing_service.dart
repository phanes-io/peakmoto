import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';

class RoutingService {
  /// Curvature-based motorcycle routing via GraphHopper
  ///
  /// curvinessLevel: 0 = fast/highway, 1 = balanced, 2 = curvy, 3 = twisty
  Future<List<RouteResult>?> calculateRoute({
    required List<LatLng> waypoints,
    int curvinessLevel = 2,
    bool avoidHighways = false,
    bool avoidTolls = true,
    bool avoidFerries = false,
    bool withAlternatives = true,
    bool isRoundTrip = false,
    double roundTripDistanceM = 50000,
    double roundTripHeading = 0,
    double? heading,
  }) async {
    if (!isRoundTrip && waypoints.length < 2) return null;
    if (isRoundTrip && waypoints.isEmpty) return null;

    // Points as [lon, lat] for GraphHopper POST
    final points = waypoints
        .map((p) => [p.longitude, p.latitude])
        .toList();

    // Avoid overrides only — curvature/road_class/speed handled by server profiles
    final priority = <Map<String, dynamic>>[];

    if (avoidHighways) {
      priority.add({'if': 'road_class == MOTORWAY', 'multiply_by': '0.01'});
    }
    if (avoidTolls) {
      priority.add({'if': 'toll == ALL', 'multiply_by': '0.05'});
    }
    if (avoidFerries) {
      priority.add({'if': 'road_environment == FERRY', 'multiply_by': '0.05'});
    }

    // Server-side profiles with optimized curvature routing
    final profileName = switch (curvinessLevel) {
      0 => 'motorcycle_fast',
      1 => 'motorcycle_balanced',
      2 => 'motorcycle_curvy',
      _ => 'motorcycle_twisty',
    };

    // Only send avoid overrides as custom_model (tolls, ferries, highways for fast)
    final overridePriority = <Map<String, dynamic>>[
      ...priority, // bad roads, surface filters
    ];

    final body = jsonEncode({
      'points': points,
      'profile': profileName,
      'points_encoded': false,
      'elevation': true,
      'instructions': true,
      'locale': 'de',
      'details': ['road_class', 'surface'],
      if (isRoundTrip) 'algorithm': 'round_trip',
      if (isRoundTrip) 'round_trip.distance': roundTripDistanceM,
      if (isRoundTrip) 'round_trip.seed': DateTime.now().millisecondsSinceEpoch % 1000,
      if (isRoundTrip && roundTripHeading > 0) 'heading': roundTripHeading,
      if (!isRoundTrip && heading != null)
        'headings': [heading.round(), ...List.filled(waypoints.length - 1, 0)],
      if (!isRoundTrip && withAlternatives && waypoints.length == 2)
        'algorithm': 'alternative_route',
      if (!isRoundTrip && withAlternatives && waypoints.length == 2)
        'alternative_route.max_paths': 3,
      'ch.disable': true,
      if (overridePriority.isNotEmpty)
        'custom_model': {
          'priority': overridePriority,
        },
    });

    final url = '${AppConstants.routingBaseUrl}/route';
    debugPrint('[GraphHopper] POST $url (curviness: $curvinessLevel)');

    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: body)
          .timeout(const Duration(seconds: 60));

      debugPrint('[GraphHopper] Status: ${response.statusCode}, Body: ${response.body.length} bytes');

      if (response.statusCode != 200) {
        debugPrint('[GraphHopper] Error: ${response.body.substring(0, min(300, response.body.length))}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final paths = json['paths'] as List;

      final routes = <RouteResult>[];
      for (final path in paths) {
        final coords = path['points']['coordinates'] as List;
        final points = coords
            .map((c) => LatLng((c as List)[1].toDouble(), c[0].toDouble()))
            .toList();

        final distanceM = (path['distance'] as num).toDouble();
        final timeMs = (path['time'] as num).toDouble();
        final ascend = (path['ascend'] as num?)?.toDouble() ?? 0;
        final descend = (path['descend'] as num?)?.toDouble() ?? 0;

        routes.add(RouteResult(
          points: points,
          distanceKm: distanceM / 1000,
          durationS: timeMs / 1000,
          ascentM: ascend,
          descentM: descend,
          instructions: path['instructions'] as List? ?? [],
        ));
      }

      debugPrint('[GraphHopper] ${routes.length} route(s) found');
      return routes.isNotEmpty ? routes : null;
    } catch (e, st) {
      debugPrint('[GraphHopper] Exception: $e');
      debugPrint('[GraphHopper] Stack: $st');
      return null;
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationS;
  final double ascentM;
  final double descentM;
  final List<dynamic> instructions;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationS,
    this.ascentM = 0,
    this.descentM = 0,
    this.instructions = const [],
  });

  String get distanceFormatted {
    if (distanceKm >= 100) return '${distanceKm.round()} km';
    if (distanceKm >= 1) return '${distanceKm.toStringAsFixed(1)} km';
    return '${(distanceKm * 1000).round()} m';
  }

  String get durationFormatted {
    final totalMin = durationS / 60;
    final hours = (totalMin / 60).floor();
    final mins = (totalMin % 60).round();
    if (hours > 0) return '${hours}h ${mins}min';
    return '$mins min';
  }

  String get ascentFormatted => '${ascentM.round()} m';
}
