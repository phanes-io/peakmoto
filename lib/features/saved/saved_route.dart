import 'package:latlong2/latlong.dart';

class SavedWaypoint {
  final double lat;
  final double lng;
  final String name;

  const SavedWaypoint({required this.lat, required this.lng, required this.name});

  LatLng get position => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'name': name};

  factory SavedWaypoint.fromJson(Map<String, dynamic> json) => SavedWaypoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        name: json['name'] as String? ?? '',
      );
}

class SavedRoute {
  final String id;
  final String name;
  final DateTime createdAt;
  final double distanceKm;
  final double durationS;
  final double ascentM;
  final List<List<double>> points; // [[lat, lng], ...]
  final List<SavedWaypoint> waypoints;

  const SavedRoute({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.distanceKm,
    required this.durationS,
    this.ascentM = 0,
    required this.points,
    required this.waypoints,
  });

  List<LatLng> get latLngPoints =>
      points.map((p) => LatLng(p[0], p[1])).toList();

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

  String get dateFormatted {
    final d = createdAt;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'distanceKm': distanceKm,
        'durationS': durationS,
        'ascentM': ascentM,
        'points': points,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        durationS: (json['durationS'] as num).toDouble(),
        ascentM: (json['ascentM'] as num?)?.toDouble() ?? 0,
        points: (json['points'] as List)
            .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
        waypoints: (json['waypoints'] as List?)
                ?.map((w) => SavedWaypoint.fromJson(w as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
