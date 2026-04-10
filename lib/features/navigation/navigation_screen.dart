import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../routing/routing_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.route,
    required this.allWaypoints,
    this.onReroute,
  });

  final RouteResult route;

  /// All waypoints so we can reroute to the remaining ones
  final List<LatLng> allWaypoints;

  /// Called when the user deviates and we need a new route
  final Future<RouteResult?> Function(LatLng from, List<LatLng> remaining)?
      onReroute;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _mapController = MapController();
  final _tts = FlutterTts();

  late RouteResult _route;
  LatLng? _currentPosition;
  double _heading = 0;
  int _currentStep = 0;
  bool _rerouting = false;
  bool _showManeuverList = false;

  StreamSubscription<Position>? _positionSub;

  // TTS state — avoid spamming
  int _lastSpokenStep = -1;
  bool _spokenFarAnnounce = false;

  static const _rerouteThresholdM = 75.0;
  static const _advanceThresholdM = 35.0;
  static const _ttsFarDistanceM = 200.0;
  static const _ttsNearDistanceM = 50.0;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _initTts();
    _startGpsTracking();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  void _startGpsTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _currentPosition = newPos;
      _heading = pos.heading;
    });

    // Move map to follow user
    _mapController.moveAndRotate(newPos, _mapController.camera.zoom < 15 ? 15 : _mapController.camera.zoom, 0);

    // Check if we should advance instruction
    _checkInstructionAdvance(newPos);

    // Check if off route → reroute
    _checkOffRoute(newPos);

    // TTS announcements
    _checkTts(newPos);
  }

  void _checkInstructionAdvance(LatLng pos) {
    if (_currentStep >= _route.instructions.length - 1) return;

    // Get the interval of route points for the next instruction
    final nextInstr = _route.instructions[_currentStep + 1] as Map<String, dynamic>;
    final nextInterval = nextInstr['interval'] as List?;
    if (nextInterval == null || nextInterval.isEmpty) return;

    final nextPointIdx = (nextInterval[0] as num).toInt();
    if (nextPointIdx >= _route.points.length) return;
    final nextPoint = _route.points[nextPointIdx];

    final dist = const Distance().as(LengthUnit.Meter, pos, nextPoint);
    if (dist < _advanceThresholdM) {
      setState(() {
        _currentStep++;
        _spokenFarAnnounce = false;
      });
    }
  }

  void _checkOffRoute(LatLng pos) {
    if (_rerouting || widget.onReroute == null) return;

    final minDist = _minDistanceToRoute(pos);
    if (minDist > _rerouteThresholdM) {
      _performReroute(pos);
    }
  }

  double _minDistanceToRoute(LatLng pos) {
    const dist = Distance();
    double minD = double.infinity;
    for (final p in _route.points) {
      final d = dist.as(LengthUnit.Meter, pos, p);
      if (d < minD) minD = d;
      if (d < _rerouteThresholdM) break; // early exit
    }
    return minD;
  }

  Future<void> _performReroute(LatLng from) async {
    setState(() => _rerouting = true);

    // Keep remaining waypoints (skip start, keep intermediate + destination)
    final remaining = widget.allWaypoints.length > 1
        ? widget.allWaypoints.sublist(1)
        : widget.allWaypoints;

    final newRoute = await widget.onReroute!(from, remaining);
    if (newRoute != null && mounted) {
      await _tts.speak('Route wird neu berechnet');
      setState(() {
        _route = newRoute;
        _currentStep = 0;
        _lastSpokenStep = -1;
        _spokenFarAnnounce = false;
        _rerouting = false;
      });
    } else {
      if (mounted) setState(() => _rerouting = false);
    }
  }

  void _checkTts(LatLng pos) {
    if (_currentStep >= _route.instructions.length) return;

    final instr = _route.instructions[_currentStep] as Map<String, dynamic>;
    final interval = instr['interval'] as List?;
    if (interval == null || interval.isEmpty) return;

    final pointIdx = (interval[0] as num).toInt();
    if (pointIdx >= _route.points.length) return;
    final instrPoint = _route.points[pointIdx];

    final dist = const Distance().as(LengthUnit.Meter, pos, instrPoint);
    final text = instr['text'] as String? ?? '';

    // Far announce (~200m)
    if (!_spokenFarAnnounce &&
        _lastSpokenStep != _currentStep &&
        dist <= _ttsFarDistanceM &&
        dist > _ttsNearDistanceM) {
      _spokenFarAnnounce = true;
      _tts.speak('In ${_formatDistanceSpoken(dist)}, $text');
    }

    // Near announce (~50m)
    if (_lastSpokenStep != _currentStep && dist <= _ttsNearDistanceM) {
      _lastSpokenStep = _currentStep;
      _tts.speak(text);
    }
  }

  String _formatDistanceSpoken(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} Kilometern';
    final rounded = (m / 50).round() * 50; // round to nearest 50
    return '$rounded Metern';
  }

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  /// Remaining distance from current step onward
  double get _remainingDistanceM {
    double total = 0;
    for (int i = _currentStep; i < _route.instructions.length; i++) {
      final instr = _route.instructions[i] as Map<String, dynamic>;
      total += (instr['distance'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// Remaining time from current step onward
  double get _remainingTimeS {
    double total = 0;
    for (int i = _currentStep; i < _route.instructions.length; i++) {
      final instr = _route.instructions[i] as Map<String, dynamic>;
      total += (instr['time'] as num?)?.toDouble() ?? 0;
    }
    return total / 1000; // GraphHopper sends ms
  }

  String _formatRemainingDistance(double m) {
    if (m >= 1000) {
      final km = m / 1000;
      if (km >= 100) return '${km.round()} km';
      return '${km.toStringAsFixed(1)} km';
    }
    return '${m.round()} m';
  }

  String _formatRemainingTime(double seconds) {
    final totalMin = seconds / 60;
    final hours = (totalMin / 60).floor();
    final mins = (totalMin % 60).round();
    if (hours > 0) return '${hours}h ${mins}min';
    return '$mins min';
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
  void dispose() {
    _positionSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentInstr = _currentStep < _route.instructions.length
        ? _route.instructions[_currentStep] as Map<String, dynamic>
        : <String, dynamic>{};
    final sign = currentInstr['sign'] as int? ?? 0;
    final instrText = currentInstr['text'] as String? ?? '';
    final instrDist = (currentInstr['distance'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _route.points.isNotEmpty
                  ? _route.points.first
                  : LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              initialZoom: 16,
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
                    points: _route.points,
                    strokeWidth: 14,
                    color: AppColors.amber.withValues(alpha: 0.25),
                  ),
                ],
              ),
              // Route line
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route.points,
                    strokeWidth: 6,
                    color: AppColors.amber,
                  ),
                ],
              ),
              // Position marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 32,
                      height: 32,
                      child: Transform.rotate(
                        angle: _heading * 3.14159265 / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF007AFF).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top: Current maneuver card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => setState(() => _showManeuverList = !_showManeuverList),
              child: Container(
                color: AppColors.amber,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: Row(
                      children: [
                        Icon(_signToIcon(sign), size: 56, color: Colors.black),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDistance(instrDist),
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                instrText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Expand/collapse indicator
                        Icon(
                          _showManeuverList
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.black54,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Maneuver list overlay
          if (_showManeuverList)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 0,
              right: 0,
              bottom: 100 + MediaQuery.of(context).padding.bottom,
              child: Container(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _route.instructions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 0.5,
                    indent: 64,
                    color: theme.dividerColor,
                  ),
                  itemBuilder: (context, index) {
                    final instr =
                        _route.instructions[index] as Map<String, dynamic>;
                    final s = instr['sign'] as int? ?? 0;
                    final t = instr['text'] as String? ?? '';
                    final d = (instr['distance'] as num?)?.toDouble() ?? 0;
                    final isCurrent = index == _currentStep;
                    final isPast = index < _currentStep;

                    return Container(
                      color: isCurrent
                          ? AppColors.amber.withValues(alpha: 0.15)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Icon(
                              _signToIcon(s),
                              size: 28,
                              color: isPast
                                  ? theme.disabledColor
                                  : isCurrent
                                      ? AppColors.amber
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isCurrent ? FontWeight.w600 : FontWeight.w400,
                                color: isPast
                                    ? theme.disabledColor
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            _formatDistance(d),
                            style: TextStyle(
                              fontSize: 14,
                              color: isPast
                                  ? theme.disabledColor
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Rerouting indicator
          if (_rerouting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.amber,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Route wird neu berechnet...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom bar: remaining distance, time, stop button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  // Remaining info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatRemainingDistance(_remainingDistanceM),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatRemainingTime(_remainingTimeS)} verbleibend',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Stop button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Stop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
