import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'routing_service.dart';

final routingServiceProvider = Provider((_) => RoutingService());

final routingProvider = StateNotifierProvider<RoutingNotifier, RoutingState>((ref) {
  return RoutingNotifier(ref.read(routingServiceProvider));
});

class Waypoint {
  final LatLng position;
  final String name;

  const Waypoint({required this.position, required this.name});
}

class RoutePreferences {
  final int curvinessLevel; // 0=fast, 1=balanced, 2=curvy, 3=twisty
  final bool avoidHighways;
  final bool avoidTolls;
  final bool avoidFerries;

  const RoutePreferences({
    this.curvinessLevel = 2,
    this.avoidHighways = false,
    this.avoidTolls = true,
    this.avoidFerries = false,
  });

  RoutePreferences copyWith({
    int? curvinessLevel,
    bool? avoidHighways,
    bool? avoidTolls,
    bool? avoidFerries,
  }) {
    return RoutePreferences(
      curvinessLevel: curvinessLevel ?? this.curvinessLevel,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidFerries: avoidFerries ?? this.avoidFerries,
    );
  }
}

class RoutingState {
  final List<Waypoint> waypoints;
  final List<RouteResult> routes;
  final int selectedRouteIndex;
  final bool loading;
  final RoutePreferences prefs;
  final bool isRoundTrip;
  final double roundTripDistanceM;
  final double roundTripHeading;

  const RoutingState({
    this.waypoints = const [],
    this.routes = const [],
    this.selectedRouteIndex = 0,
    this.loading = false,
    this.prefs = const RoutePreferences(),
    this.isRoundTrip = false,
    this.roundTripDistanceM = 0,
    this.roundTripHeading = 0,
  });

  bool get hasRoute => routes.isNotEmpty;
  bool get hasWaypoints => waypoints.length >= 2 || isRoundTrip;
  bool get hasAlternatives => routes.length > 1;

  RouteResult? get route => routes.isNotEmpty ? routes[selectedRouteIndex] : null;

  LatLng? get origin => waypoints.isNotEmpty ? waypoints.first.position : null;
  LatLng? get destination => waypoints.length >= 2 ? waypoints.last.position : null;
  String? get destinationName => waypoints.length >= 2 ? waypoints.last.name : null;

  List<LatLng> get allPositions => waypoints.map((w) => w.position).toList();

  RoutingState copyWith({
    List<Waypoint>? waypoints,
    List<RouteResult>? routes,
    int? selectedRouteIndex,
    bool? loading,
    RoutePreferences? prefs,
    bool? isRoundTrip,
    double? roundTripDistanceM,
    double? roundTripHeading,
    bool clearRoutes = false,
  }) {
    return RoutingState(
      waypoints: waypoints ?? this.waypoints,
      routes: clearRoutes ? const [] : (routes ?? this.routes),
      selectedRouteIndex: selectedRouteIndex ?? this.selectedRouteIndex,
      loading: loading ?? this.loading,
      prefs: prefs ?? this.prefs,
      isRoundTrip: isRoundTrip ?? this.isRoundTrip,
      roundTripDistanceM: roundTripDistanceM ?? this.roundTripDistanceM,
      roundTripHeading: roundTripHeading ?? this.roundTripHeading,
    );
  }
}

class RoutingNotifier extends StateNotifier<RoutingState> {
  final RoutingService _service;

  RoutingNotifier(this._service) : super(const RoutingState());

  Future<void> routeTo({
    required LatLng origin,
    required LatLng destination,
    required String destinationName,
  }) async {
    state = RoutingState(
      waypoints: [
        Waypoint(position: origin, name: 'Start'),
        Waypoint(position: destination, name: destinationName),
      ],
      loading: true,
      prefs: state.prefs,
    );
    await _recalculate();
  }

  Future<void> roundTrip({
    required LatLng origin,
    required double distanceM,
    required double heading,
    required int curvinessLevel,
  }) async {
    state = RoutingState(
      waypoints: [Waypoint(position: origin, name: 'Round Trip')],
      loading: true,
      prefs: state.prefs.copyWith(curvinessLevel: curvinessLevel),
      isRoundTrip: true,
      roundTripDistanceM: distanceM,
      roundTripHeading: heading,
    );
    await _recalculate();
  }

  Future<void> addWaypoint(LatLng position, String name) async {
    if (state.waypoints.length < 2) return;
    final updated = [...state.waypoints];
    updated.insert(updated.length - 1, Waypoint(position: position, name: name));
    state = state.copyWith(waypoints: updated, loading: true);
    await _recalculate();
  }

  Future<void> removeWaypoint(int index) async {
    if (state.waypoints.length <= 2) return;
    if (index == 0 || index == state.waypoints.length - 1) return;
    final updated = [...state.waypoints]..removeAt(index);
    state = state.copyWith(waypoints: updated, loading: true);
    await _recalculate();
  }

  Future<void> updatePreferences(RoutePreferences prefs) async {
    state = state.copyWith(prefs: prefs);
    if (state.hasWaypoints) {
      state = state.copyWith(loading: true);
      await _recalculate();
    }
  }

  Future<void> replaceWaypoint(int index, LatLng position, String name) async {
    final oldWaypoints = state.waypoints;
    final updated = [...state.waypoints];
    updated[index] = Waypoint(position: position, name: name);
    state = state.copyWith(waypoints: updated, loading: true);
    await _recalculate(fallbackWaypoints: oldWaypoints);
  }

  void selectRoute(int index) {
    if (index >= 0 && index < state.routes.length) {
      state = state.copyWith(selectedRouteIndex: index);
    }
  }

  Future<void> _recalculate({List<Waypoint>? fallbackWaypoints}) async {
    final oldRoutes = state.routes;
    final results = await _service.calculateRoute(
      waypoints: state.allPositions,
      curvinessLevel: state.prefs.curvinessLevel,
      avoidHighways: state.prefs.avoidHighways || state.isRoundTrip,
      avoidTolls: state.prefs.avoidTolls,
      avoidFerries: state.prefs.avoidFerries,
      isRoundTrip: state.isRoundTrip,
      roundTripDistanceM: state.roundTripDistanceM,
      roundTripHeading: state.roundTripHeading,
      withAlternatives: !state.isRoundTrip,
    );
    if (results != null) {
      state = state.copyWith(
        routes: results,
        selectedRouteIndex: 0,
        loading: false,
      );
    } else {
      // Revert waypoints and keep old route on failure
      state = state.copyWith(
        waypoints: fallbackWaypoints ?? state.waypoints,
        routes: oldRoutes,
        loading: false,
      );
    }
  }

  void clear() {
    state = RoutingState(prefs: state.prefs, isRoundTrip: false);
  }
}
