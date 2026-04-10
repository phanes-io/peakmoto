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
  }) async {
    if (!isRoundTrip && waypoints.length < 2) return null;
    if (isRoundTrip && waypoints.isEmpty) return null;

    // Points as [lon, lat] for GraphHopper POST
    final points = waypoints
        .map((p) => [p.longitude, p.latitude])
        .toList();

    // Build priority rules – completely different per mode
    final priority = <Map<String, dynamic>>[];

    // === Always: no bad roads for motorcycles ===
    priority.add({'if': 'road_class == TRACK || road_class == BRIDLEWAY || road_class == STEPS || road_class == FOOTWAY || road_class == CYCLEWAY', 'multiply_by': '0.01'});
    priority.add({'if': 'road_class == SERVICE', 'multiply_by': '0.1'});
    priority.add({'if': 'surface == GRAVEL || surface == DIRT || surface == UNPAVED || surface == SAND', 'multiply_by': '0.05'});
    priority.add({'if': 'surface == COMPACTED', 'multiply_by': '0.2'});
    priority.add({'if': 'track_type != MISSING && track_type != GRADE1', 'multiply_by': '0.05'});

    switch (curvinessLevel) {
      case 0: // === FAST: Shortest time, highways welcome ===
        if (avoidHighways) {
          priority.add({'if': 'road_class == MOTORWAY', 'multiply_by': '0.01'});
        }
        // Slight penalty for residential but otherwise fast
        priority.add({'if': 'road_class == SERVICE', 'multiply_by': '0.5'});
        priority.add({'if': 'road_class == RESIDENTIAL || road_class == LIVING_STREET', 'multiply_by': '0.6'});

      case 1: // === BALANCED: Prefer good roads, avoid highways somewhat ===
        priority.add({'if': 'road_class == MOTORWAY', 'multiply_by': avoidHighways ? '0.01' : '0.4'});
        priority.add({'if': 'road_class == TRUNK', 'multiply_by': avoidHighways ? '0.1' : '0.6'});
        priority.add({'if': 'road_class == SERVICE', 'multiply_by': '0.3'});
        priority.add({'if': 'road_class == RESIDENTIAL || road_class == LIVING_STREET', 'multiply_by': '0.4'});
        priority.add({'if': 'road_class == UNCLASSIFIED', 'multiply_by': '0.6'});
        // Mild curvature preference
        priority.add({'if': 'curvature >= 0.95', 'multiply_by': '0.7'});
        // Mild city avoidance
        priority.add({'if': 'urban_density == CITY', 'multiply_by': '0.5'});

      case 2: // === CURVY: Landstraßen, keine Highways, Kurven bevorzugen ===
        priority.add({'if': 'road_class == MOTORWAY', 'multiply_by': '0.01'});
        priority.add({'if': 'road_class == TRUNK', 'multiply_by': '0.1'});
        priority.add({'if': 'road_class == SERVICE', 'multiply_by': '0.2'});
        priority.add({'if': 'road_class == RESIDENTIAL || road_class == LIVING_STREET', 'multiply_by': '0.3'});
        priority.add({'if': 'road_class == UNCLASSIFIED', 'multiply_by': '0.5'});
        // Strong curvature preference
        priority.add({'if': 'curvature >= 0.95', 'multiply_by': '0.3'});
        priority.add({'if': 'curvature >= 0.85', 'multiply_by': '0.5'});
        // Avoid cities
        priority.add({'if': 'urban_density == RESIDENTIAL', 'multiply_by': '0.5'});
        priority.add({'if': 'urban_density == CITY', 'multiply_by': '0.2'});

      default: // === TWISTY: Maximum kurvig, große Umwege akzeptiert ===
        priority.add({'if': 'road_class == MOTORWAY', 'multiply_by': '0.01'});
        priority.add({'if': 'road_class == TRUNK', 'multiply_by': '0.05'});
        priority.add({'if': 'road_class == PRIMARY', 'multiply_by': '0.5'});
        priority.add({'if': 'road_class == SERVICE', 'multiply_by': '0.1'});
        priority.add({'if': 'road_class == RESIDENTIAL || road_class == LIVING_STREET', 'multiply_by': '0.15'});
        priority.add({'if': 'road_class == UNCLASSIFIED', 'multiply_by': '0.4'});
        // Extreme curvature preference – gerade Straßen hart bestrafen
        priority.add({'if': 'curvature >= 0.95', 'multiply_by': '0.1'});
        priority.add({'if': 'curvature >= 0.85', 'multiply_by': '0.3'});
        priority.add({'if': 'curvature >= 0.70', 'multiply_by': '0.5'});
        // Hard city avoidance
        priority.add({'if': 'urban_density == RESIDENTIAL', 'multiply_by': '0.3'});
        priority.add({'if': 'urban_density == CITY', 'multiply_by': '0.1'});
    }

    // Tolls
    if (avoidTolls) {
      priority.add({'if': 'toll == ALL', 'multiply_by': '0.05'});
    }

    // Ferries
    if (avoidFerries) {
      priority.add({'if': 'road_environment == FERRY', 'multiply_by': '0.05'});
    }

    final body = jsonEncode({
      'points': points,
      'profile': 'motorcycle',
      'points_encoded': false,
      'elevation': true,
      'instructions': true,
      'locale': 'de',
      'details': ['road_class', 'surface'],
      if (isRoundTrip) 'algorithm': 'round_trip',
      if (isRoundTrip) 'round_trip.distance': roundTripDistanceM,
      if (isRoundTrip) 'round_trip.seed': DateTime.now().millisecondsSinceEpoch % 1000,
      if (isRoundTrip && roundTripHeading > 0) 'heading': roundTripHeading,
      if (!isRoundTrip && withAlternatives && waypoints.length == 2)
        'algorithm': 'alternative_route',
      if (!isRoundTrip && withAlternatives && waypoints.length == 2)
        'alternative_route.max_paths': 3,
      'ch.disable': true,
      'custom_model': {
        'priority': priority,
        'speed': [
          {'if': 'road_class == MOTORWAY', 'limit_to': '120'},
          {'if': 'road_class == TRUNK', 'limit_to': '90'},
          {'if': 'road_class == PRIMARY', 'limit_to': '80'},
          {'if': 'road_class == SECONDARY', 'limit_to': '70'},
          {'if': 'road_class == TERTIARY', 'limit_to': '60'},
          {'if': 'road_class == RESIDENTIAL || road_class == LIVING_STREET', 'limit_to': '40'},
          {'if': 'road_class == SERVICE', 'limit_to': '20'},
          {'if': 'road_class == UNCLASSIFIED', 'limit_to': '50'},
        ],
        'distance_influence': 90,
      },
    });

    final url = '${AppConstants.routingBaseUrl}/route';
    debugPrint('[GraphHopper] POST $url (curviness: $curvinessLevel)');

    try {
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: body)
          .timeout(const Duration(seconds: 30));

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
