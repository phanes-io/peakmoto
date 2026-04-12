import 'package:latlong2/latlong.dart';

class FeedbackData {
  final int rating; // 0 = skipped, 1-5 = stars
  final String profile;
  final LatLng start;
  final LatLng end;
  final String? endName;
  final List<LatLng> waypoints;
  final double distanceKm;
  final int durationMin;
  final int turnCount;
  final bool arrived;
  final String? comment;
  final String? appVersion;

  const FeedbackData({
    required this.rating,
    required this.profile,
    required this.start,
    required this.end,
    this.endName,
    this.waypoints = const [],
    required this.distanceKm,
    required this.durationMin,
    required this.turnCount,
    required this.arrived,
    this.comment,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'profile': profile,
        'start': {'lat': start.latitude, 'lng': start.longitude},
        'end': {
          'lat': end.latitude,
          'lng': end.longitude,
          if (endName != null) 'name': endName,
        },
        'waypoints': waypoints
            .map((w) => {'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'turn_count': turnCount,
        'arrived': arrived,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        if (appVersion != null) 'app_version': appVersion,
      };
}
