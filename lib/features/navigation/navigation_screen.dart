import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../routing/routing_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.route});

  final RouteResult route;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _mapController = MapController();
  int _currentStep = 0;

  Map<String, dynamic> get _currentInstruction =>
      _currentStep < widget.route.instructions.length
          ? widget.route.instructions[_currentStep] as Map<String, dynamic>
          : {};

  String get _nextText => _currentInstruction['text'] as String? ?? '';
  double get _nextDistance => (_currentInstruction['distance'] as num?)?.toDouble() ?? 0;

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  IconData _signToIcon(int sign) {
    return switch (sign) {
      -3 => Icons.turn_sharp_left_rounded,
      -2 => Icons.turn_left_rounded,
      -1 => Icons.turn_slight_left_rounded,
      0 => Icons.straight_rounded,
      1 => Icons.turn_slight_right_rounded,
      2 => Icons.turn_right_rounded,
      3 => Icons.turn_sharp_right_rounded,
      4 => Icons.flag_rounded,
      6 => Icons.roundabout_right_rounded,
      _ => Icons.straight_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sign = _currentInstruction['sign'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.amber,
      body: Column(
        children: [
          // Maneuver card
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              color: AppColors.amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_signToIcon(sign), size: 48, color: Colors.black),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDistance(_nextDistance),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              _nextText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.route.points.isNotEmpty
                    ? widget.route.points.first
                    : LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? AppConstants.tileUrlDark
                      : AppConstants.tileUrlLight,
                  userAgentPackageName: 'app.peakmoto.peakmoto',
                ),
                // Route glow
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.route.points,
                      strokeWidth: 14,
                      color: AppColors.amber.withValues(alpha: 0.25),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.route.points,
                      strokeWidth: 6,
                      color: AppColors.amber,
                    ),
                  ],
                ),
                // Position marker
                MarkerLayer(
                  markers: [
                    if (widget.route.points.isNotEmpty)
                      Marker(
                        point: widget.route.points.first,
                        width: 28,
                        height: 28,
                        child: Container(
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
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom bar
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.route.distanceFormatted,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      widget.route.durationFormatted,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Step through maneuvers (for desktop testing)
                GestureDetector(
                  onTap: () {
                    if (_currentStep > 0) setState(() => _currentStep--);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_currentStep < widget.route.instructions.length - 1) {
                      setState(() => _currentStep++);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
