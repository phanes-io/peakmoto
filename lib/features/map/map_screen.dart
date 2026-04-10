import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/map_button.dart';
import '../../shared/widgets/tab_bar_item.dart';
import '../routing/route_card.dart';
import '../routing/route_header.dart';
import '../navigation/navigation_screen.dart';
import '../routing/round_trip_sheet.dart';
import '../saved/saved_routes_sheet.dart';
import '../routing/routing_provider.dart';
import '../routing/routing_service.dart';
import '../search/search_service.dart';
import '../search/search_sheet.dart';
import '../settings/settings_sheet.dart';
import 'location_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(locationProvider.notifier).locate());

    ref.listenManual(routingProvider, (prev, next) {
      if (prev?.loading == true && !next.loading && next.route != null) {
        Future.microtask(() => _fitRoute());
      }
    });
  }

  void _openRouteMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _RouteMenuItem(
                icon: Icons.search_rounded,
                label: 'Ziel suchen',
                subtitle: 'Route zu einem bestimmten Ort',
                onTap: () {
                  Navigator.pop(context);
                  _openSearch();
                },
              ),
              Divider(height: 0.5, indent: 56, color: theme.dividerColor),
              _RouteMenuItem(
                icon: Icons.loop_rounded,
                label: 'Rundtour',
                subtitle: 'Eine Runde fahren und zurückkommen',
                onTap: () {
                  Navigator.pop(context);
                  _openRoundTrip();
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRoundTrip() async {
    final config = await showModalBottomSheet<RoundTripConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RoundTripSheet(),
    );

    if (config == null) return;

    final location = ref.read(locationProvider);
    final origin = location.position ??
        LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    // Convert hours to meters (~60km/h average)
    final distanceM = config.durationHours * 60000;

    ref.read(routingProvider.notifier).roundTrip(
          origin: origin,
          distanceM: distanceM,
          heading: config.heading,
          curvinessLevel: config.curvinessLevel,
        );
  }

  void _startNavigation(RouteResult route) {
    final routing = ref.read(routingProvider);
    final waypoints = routing.allPositions;
    final service = ref.read(routingServiceProvider);
    final prefs = routing.prefs;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: route,
          allWaypoints: waypoints,
          onReroute: (from, remaining) async {
            final points = [from, ...remaining];
            final results = await service.calculateRoute(
              waypoints: points,
              curvinessLevel: prefs.curvinessLevel,
              avoidHighways: prefs.avoidHighways,
              avoidTolls: prefs.avoidTolls,
              avoidFerries: prefs.avoidFerries,
            );
            return results?.first;
          },
        ),
      ),
    );
  }

  void _addWaypoint(LatLng point) {
    ref.read(routingProvider.notifier).addWaypoint(point, 'Waypoint');
  }

  Future<void> _openSearch() async {
    final location = ref.read(locationProvider);
    final result = await showModalBottomSheet<SearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchSheet(userLocation: location.position),
    );

    if (result == null) return;

    final origin = location.position ??
        LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    _fitPoints([origin, result.position]);

    ref.read(routingProvider.notifier).routeTo(
          origin: origin,
          destination: result.position,
          destinationName: result.title,
        );
  }

  void _fitPoints(List<LatLng> points) {
    if (points.isEmpty) return;

    var minLat = points[0].latitude;
    var maxLat = points[0].latitude;
    var minLng = points[0].longitude;
    var maxLng = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 300),
      ),
    );
  }

  void _fitRoute() {
    final routing = ref.read(routingProvider);
    if (routing.route != null) {
      _fitPoints(routing.route!.points);
    } else if (routing.origin != null && routing.destination != null) {
      _fitPoints([routing.origin!, routing.destination!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final location = ref.watch(locationProvider);
    final routing = ref.watch(routingProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              initialZoom: 10,
              onLongPress: routing.hasRoute
                  ? (_, point) => _addWaypoint(point)
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? AppConstants.tileUrlDark
                    : AppConstants.tileUrlLight,
                userAgentPackageName: 'app.peakmoto.peakmoto',
              ),
              // Alternative routes (grey, tappable)
              if (routing.hasAlternatives)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < routing.routes.length; i++)
                      if (i != routing.selectedRouteIndex)
                        Polyline(
                          points: routing.routes[i].points,
                          strokeWidth: 4,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.15),
                        ),
                  ],
                ),
              // Selected route glow
              if (routing.route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routing.route!.points,
                      strokeWidth: 12,
                      color: AppColors.amber.withValues(alpha: 0.25),
                    ),
                  ],
                ),
              // Selected route line
              if (routing.route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routing.route!.points,
                      strokeWidth: 4,
                      color: AppColors.amber,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (location.position != null)
                    Marker(
                      point: location.position!,
                      width: 24,
                      height: 24,
                      child: const _LocationDot(),
                    ),
                  for (int i = 0; i < routing.waypoints.length; i++)
                    Marker(
                      point: routing.waypoints[i].position,
                      width: 36,
                      height: 36,
                      child: _WaypointPin(
                        color: i == 0
                            ? const Color(0xFF34C759)
                            : i == routing.waypoints.length - 1
                                ? AppColors.amber
                                : AppColors.amberDark,
                        icon: i == 0
                            ? Icons.navigation_rounded
                            : i == routing.waypoints.length - 1
                                ? Icons.flag_rounded
                                : Icons.circle,
                        label: i > 0 && i < routing.waypoints.length - 1
                            ? '$i'
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top bar: Search or Route header
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: (routing.hasRoute || routing.loading)
                ? RouteHeader(
                    waypoints: routing.waypoints,
                    onAddStop: () async {
                      final result = await showModalBottomSheet<SearchResult>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SearchSheet(userLocation: location.position),
                      );
                      if (result != null) {
                        ref.read(routingProvider.notifier).addWaypoint(
                              result.position,
                              result.title,
                            );
                      }
                    },
                    onTapWaypoint: (i) async {
                      final result = await showModalBottomSheet<SearchResult>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SearchSheet(userLocation: location.position),
                      );
                      if (result != null) {
                        ref.read(routingProvider.notifier).replaceWaypoint(
                              i,
                              result.position,
                              result.title,
                            );
                      }
                    },
                    onRemoveWaypoint: (i) =>
                        ref.read(routingProvider.notifier).removeWaypoint(i),
                    onClose: () => ref.read(routingProvider.notifier).clear(),
                  )
                : GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: theme.textTheme.bodyMedium?.color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Wohin?',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PeakMoto',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Map controls
          Positioned(
            right: 16,
            bottom: bottomPadding + ((routing.hasRoute || routing.loading) ? 240 : 110),
            child: Column(
              children: [
                MapButton(
                  icon: Icons.my_location_rounded,
                  onPressed: () {
                    final pos = location.position;
                    if (pos != null) _mapController.move(pos, 14);
                  },
                ),
                const SizedBox(height: 8),
                if (routing.hasRoute)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MapButton(icon: Icons.fit_screen_rounded, onPressed: _fitRoute),
                  ),
                MapButton(
                  icon: Icons.add_rounded,
                  onPressed: () {
                    final cam = _mapController.camera;
                    _mapController.move(cam.center, cam.zoom + 1);
                  },
                ),
                const SizedBox(height: 2),
                MapButton(
                  icon: Icons.remove_rounded,
                  onPressed: () {
                    final cam = _mapController.camera;
                    _mapController.move(cam.center, cam.zoom - 1);
                  },
                ),
              ],
            ),
          ),

          // Route card
          if (routing.hasRoute || routing.loading)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomPadding + 80,
              child: routing.loading
                  ? RouteCardSkeleton(destinationName: routing.destinationName ?? '')
                  : RouteCard(
                      route: routing.route!,
                      routes: routing.routes,
                      selectedIndex: routing.selectedRouteIndex,
                      destinationName: routing.destinationName ?? '',
                      prefs: routing.prefs,
                      onPrefsChanged: (p) =>
                          ref.read(routingProvider.notifier).updatePreferences(p),
                      onRouteSelected: (i) =>
                          ref.read(routingProvider.notifier).selectRoute(i),
                      onClose: () => ref.read(routingProvider.notifier).clear(),
                      onStartNavigation: () => _startNavigation(routing.route!),
                    ),
            ),

          // Tab bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(left: 8, right: 8, top: 12, bottom: bottomPadding + 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TabBarItem(icon: Icons.map_rounded, label: 'Karte', isActive: !routing.hasRoute, onTap: () {}),
                  TabBarItem(
                    icon: Icons.route_rounded,
                    label: 'Route',
                    isActive: routing.hasRoute,
                    onTap: routing.hasRoute ? _fitRoute : _openRouteMenu,
                  ),
                  TabBarItem(
                    icon: Icons.bookmark_outline_rounded,
                    label: 'Gespeichert',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SavedRoutesSheet(),
                    ),
                  ),
                  TabBarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Mehr',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SettingsSheet(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaypointPin extends StatelessWidget {
  const _WaypointPin({required this.color, required this.icon, this.label});

  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: label != null
            ? Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
            : Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _RouteMenuItem extends StatelessWidget {
  const _RouteMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.amber, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }
}
