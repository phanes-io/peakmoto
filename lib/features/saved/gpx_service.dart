import 'dart:math';

import 'package:gpx/gpx.dart';
import 'package:uuid/uuid.dart';

import 'saved_route.dart';

class GpxService {
  /// Convert a SavedRoute to GPX XML string
  String export(SavedRoute route) {
    final gpx = Gpx();
    gpx.creator = 'PeakMoto';
    gpx.metadata = Metadata(
      name: route.name,
      time: route.createdAt,
    );

    // Waypoints
    for (final wp in route.waypoints) {
      gpx.wpts.add(Wpt(
        lat: wp.lat,
        lon: wp.lng,
        name: wp.name,
      ));
    }

    // Track
    final segment = Trkseg();
    for (final p in route.points) {
      segment.trkpts.add(Wpt(lat: p[0], lon: p[1]));
    }

    gpx.trks.add(Trk(
      name: route.name,
      trksegs: [segment],
    ));

    return GpxWriter().asString(gpx, pretty: true);
  }

  /// Parse a GPX XML string into a SavedRoute
  SavedRoute? import(String gpxString) {
    try {
      final gpx = GpxReader().fromString(gpxString);

      // Extract points from tracks
      final points = <List<double>>[];
      for (final trk in gpx.trks) {
        for (final seg in trk.trksegs) {
          for (final pt in seg.trkpts) {
            if (pt.lat != null && pt.lon != null) {
              points.add([pt.lat!, pt.lon!]);
            }
          }
        }
      }

      // Fallback: try route points if no tracks
      if (points.isEmpty) {
        for (final rte in gpx.rtes) {
          for (final pt in rte.rtepts) {
            if (pt.lat != null && pt.lon != null) {
              points.add([pt.lat!, pt.lon!]);
            }
          }
        }
      }

      if (points.isEmpty) return null;

      // Extract waypoints
      final waypoints = gpx.wpts
          .where((w) => w.lat != null && w.lon != null)
          .map((w) => SavedWaypoint(
                lat: w.lat!,
                lng: w.lon!,
                name: w.name ?? '',
              ))
          .toList();

      // Calculate distance from points
      double totalDistM = 0;
      for (int i = 1; i < points.length; i++) {
        totalDistM += _haversine(
          points[i - 1][0], points[i - 1][1],
          points[i][0], points[i][1],
        );
      }

      final name = gpx.metadata?.name ??
          gpx.trks.firstOrNull?.name ??
          'Importierte Route';

      return SavedRoute(
        id: const Uuid().v4(),
        name: name,
        createdAt: gpx.metadata?.time ?? DateTime.now(),
        distanceKm: totalDistM / 1000,
        durationS: 0,
        points: points,
        waypoints: waypoints,
      );
    } catch (_) {
      return null;
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }
}
