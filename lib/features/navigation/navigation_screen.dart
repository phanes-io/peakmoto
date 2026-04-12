import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../feedback/feedback_data.dart';
import '../feedback/feedback_dialog.dart';
import '../feedback/feedback_service.dart';
import '../routing/routing_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.route,
    required this.allWaypoints,
    required this.profileName,
    this.destinationName,
    this.onReroute,
  });

  final RouteResult route;
  final List<LatLng> allWaypoints;

  /// GraphHopper profile name used (motorcycle_curvy, etc.)
  final String profileName;

  /// Display name for the destination (last waypoint)
  final String? destinationName;

  /// Called when user deviates. Receives position, heading (degrees), remaining waypoints.
  final Future<RouteResult?> Function(LatLng from, double heading, List<LatLng> remaining)?
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
  bool _followUser = true;

  /// Index of nearest route segment (for clipping + off-route detection)
  int _nearestSegmentIdx = 0;

  /// Arrival state — dialog only shown once
  bool _arrivalShown = false;

  /// Live distance to next maneuver point (updated every GPS tick)
  double _liveDistToNextTurn = 0;

  StreamSubscription<Position>? _positionSub;

  // TTS state
  int _lastSpokenStep = -1;
  bool _spokenFarAnnounce = false;

  // Reroute cooldown
  DateTime? _lastRerouteTime;

  static const _rerouteThresholdM = 100.0;
  static const _rerouteCooldownS = 15;
  static const _advanceThresholdM = 35.0;
  static const _ttsFarDistanceM = 200.0;
  static const _ttsNearDistanceM = 50.0;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    WakelockPlus.enable();
    _initTts();
    _startGpsTracking();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [IosTextToSpeechAudioCategoryOptions.duckOthers],
    );
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

    // [Fix 1] Rotate map to match driving direction
    if (_followUser) {
      _mapController.moveAndRotate(
        newPos,
        _mapController.camera.zoom < 15 ? 15 : _mapController.camera.zoom,
        -_heading,
      );
    }

    _updateNearestSegment(newPos);

    // [Fix 2] Update live distance to next turn
    _updateLiveDistance(newPos);

    _checkInstructionAdvance(newPos);
    _checkOffRoute(newPos);
    _checkTts(newPos);
    _checkArrival(newPos);
  }

  /// Detect arrival at final destination (within 50m)
  void _checkArrival(LatLng pos) {
    if (_arrivalShown || widget.allWaypoints.isEmpty) return;
    final destination = widget.allWaypoints.last;
    final dist = const Distance().as(LengthUnit.Meter, pos, destination);
    if (dist < 50) {
      _arrivalShown = true;
      _tts.speak('Ziel erreicht');
      _showFeedbackAndExit(arrived: true);
    }
  }

  /// Show feedback dialog, submit if rating given, then exit navigation screen
  Future<void> _showFeedbackAndExit({required bool arrived}) async {
    if (!mounted) return;

    final result = await showDialog<FeedbackResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FeedbackDialog(
        distanceKm: _route.distanceKm,
        durationMin: (_route.durationS / 60).round(),
        turnCount: _route.instructions.length,
        arrived: arrived,
      ),
    );

    // Submit in background if user gave a rating
    if (result != null && result.rating > 0 && widget.allWaypoints.isNotEmpty) {
      final data = FeedbackData(
        rating: result.rating,
        profile: widget.profileName,
        start: widget.allWaypoints.first,
        end: widget.allWaypoints.last,
        endName: widget.destinationName,
        waypoints: widget.allWaypoints.length > 2
            ? widget.allWaypoints.sublist(1, widget.allWaypoints.length - 1)
            : const [],
        distanceKm: _route.distanceKm,
        durationMin: (_route.durationS / 60).round(),
        turnCount: _route.instructions.length,
        arrived: arrived,
        comment: result.comment,
        appVersion: AppConstants.appVersion,
      );
      // Fire and forget
      FeedbackService().submit(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Danke für dein Feedback!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _updateNearestSegment(LatLng pos) {
    if (_route.points.length < 2) return;

    final searchStart = max(0, _nearestSegmentIdx - 5);
    final searchEnd = min(_route.points.length - 1, _nearestSegmentIdx + 40);

    double minDist = double.infinity;
    int bestIdx = _nearestSegmentIdx;

    for (int i = searchStart; i < searchEnd; i++) {
      final d = _distToSegment(pos, _route.points[i], _route.points[i + 1]);
      if (d < minDist) {
        minDist = d;
        bestIdx = i;
      }
    }

    if (bestIdx >= _nearestSegmentIdx - 2) {
      _nearestSegmentIdx = bestIdx;
    }
  }

  /// [Fix 2] Calculate live distance from current position to the next instruction point
  void _updateLiveDistance(LatLng pos) {
    if (_currentStep >= _route.instructions.length) return;

    // Find the route point index for the NEXT instruction (the turn we're approaching)
    LatLng? nextTurnPoint;
    if (_currentStep + 1 < _route.instructions.length) {
      final nextInstr = _route.instructions[_currentStep + 1] as Map<String, dynamic>;
      final interval = nextInstr['interval'] as List?;
      if (interval != null && interval.isNotEmpty) {
        final idx = (interval[0] as num).toInt();
        if (idx < _route.points.length) {
          nextTurnPoint = _route.points[idx];
        }
      }
    }

    if (nextTurnPoint != null) {
      _liveDistToNextTurn = const Distance().as(LengthUnit.Meter, pos, nextTurnPoint);
    }
  }

  double _distToSegment(LatLng p, LatLng a, LatLng b) {
    const dist = Distance();
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final px = p.longitude, py = p.latitude;
    final dx = bx - ax, dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return dist.as(LengthUnit.Meter, p, a);
    var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return dist.as(LengthUnit.Meter, p, LatLng(ay + t * dy, ax + t * dx));
  }

  /// [Fix 4] Project current position onto the nearest segment → smooth clip point
  LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final px = p.longitude, py = p.latitude;
    final dx = bx - ax, dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return LatLng(ay + t * dy, ax + t * dx);
  }

  void _checkInstructionAdvance(LatLng pos) {
    if (_currentStep >= _route.instructions.length - 1) return;

    final nextInstr =
        _route.instructions[_currentStep + 1] as Map<String, dynamic>;
    final nextInterval = nextInstr['interval'] as List?;
    if (nextInterval == null || nextInterval.isEmpty) return;

    final nextPointIdx = (nextInterval[0] as num).toInt();
    if (nextPointIdx >= _route.points.length) return;
    final nextPoint = _route.points[nextPointIdx];

    final d = const Distance().as(LengthUnit.Meter, pos, nextPoint);
    if (d < _advanceThresholdM) {
      setState(() {
        _currentStep++;
        _spokenFarAnnounce = false;
      });
    }
  }

  void _checkOffRoute(LatLng pos) {
    if (_rerouting || widget.onReroute == null) return;

    if (_lastRerouteTime != null) {
      final elapsed = DateTime.now().difference(_lastRerouteTime!).inSeconds;
      if (elapsed < _rerouteCooldownS) return;
    }

    final minDist = _minDistanceToRoute(pos);
    if (minDist > _rerouteThresholdM) {
      _performReroute(pos);
    }
  }

  double _minDistanceToRoute(LatLng pos) {
    if (_route.points.length < 2) return 0;
    final searchStart = max(0, _nearestSegmentIdx - 5);
    final searchEnd = min(_route.points.length - 1, _nearestSegmentIdx + 30);
    double minD = double.infinity;
    for (int i = searchStart; i < searchEnd; i++) {
      final d = _distToSegment(pos, _route.points[i], _route.points[i + 1]);
      if (d < minD) minD = d;
    }
    return minD;
  }

  /// [Fix 3] Pass heading to reroute so GraphHopper routes forward, not "turn around"
  Future<void> _performReroute(LatLng from) async {
    setState(() => _rerouting = true);

    final remaining = widget.allWaypoints.length > 1
        ? widget.allWaypoints.sublist(1)
        : widget.allWaypoints;

    final newRoute = await widget.onReroute!(from, _heading, remaining);
    if (newRoute != null && mounted) {
      await _tts.speak('Route wird neu berechnet');
      setState(() {
        _route = newRoute;
        _currentStep = 0;
        _nearestSegmentIdx = 0;
        _lastSpokenStep = -1;
        _spokenFarAnnounce = false;
        _rerouting = false;
        _lastRerouteTime = DateTime.now();
      });
    } else {
      if (mounted) {
        setState(() {
          _rerouting = false;
          _lastRerouteTime = DateTime.now();
        });
      }
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

    if (!_spokenFarAnnounce &&
        _lastSpokenStep != _currentStep &&
        dist <= _ttsFarDistanceM &&
        dist > _ttsNearDistanceM) {
      _spokenFarAnnounce = true;
      _tts.speak('In ${_formatDistanceSpoken(dist)}, $text');
    }

    if (_lastSpokenStep != _currentStep && dist <= _ttsNearDistanceM) {
      _lastSpokenStep = _currentStep;
      _tts.speak(text);
    }
  }

  String _formatDistanceSpoken(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} Kilometern';
    final rounded = (m / 50).round() * 50;
    return '$rounded Metern';
  }

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  double get _remainingDistanceM {
    double total = 0;
    for (int i = _currentStep; i < _route.instructions.length; i++) {
      final instr = _route.instructions[i] as Map<String, dynamic>;
      total += (instr['distance'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get _remainingTimeS {
    double total = 0;
    for (int i = _currentStep; i < _route.instructions.length; i++) {
      final instr = _route.instructions[i] as Map<String, dynamic>;
      total += (instr['time'] as num?)?.toDouble() ?? 0;
    }
    return total / 1000;
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

  /// [Fix 4] Route points remaining, with smooth projected start point
  List<LatLng> get _remainingRoutePoints {
    if (_route.points.length < 2) return _route.points;
    if (_nearestSegmentIdx >= _route.points.length - 1) return [_route.points.last];

    final a = _route.points[_nearestSegmentIdx];
    final b = _route.points[_nearestSegmentIdx + 1];

    // Project current position onto the segment for smooth clipping
    final projectedPoint = _currentPosition != null
        ? _projectOntoSegment(_currentPosition!, a, b)
        : a;

    return [projectedPoint, ..._route.points.sublist(_nearestSegmentIdx + 1)];
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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

    // [Fix 2] Use live distance instead of static instruction distance
    final displayDist = _currentPosition != null ? _liveDistToNextTurn : 0.0;

    final remainingPoints = _remainingRoutePoints;

    return Scaffold(
      body: Stack(
        children: [
          // Map with touch detection
          Listener(
            onPointerDown: (_) {
              if (_followUser) setState(() => _followUser = false);
            },
            child: FlutterMap(
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
                tileProvider: const FMTCStore('peakmoto_tiles').getTileProvider(),
              ),
              // Route glow (remaining only)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: remainingPoints,
                    strokeWidth: 14,
                    color: AppColors.amber.withValues(alpha: 0.25),
                  ),
                ],
              ),
              // Route line (remaining only)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: remainingPoints,
                    strokeWidth: 6,
                    color: AppColors.amber,
                  ),
                ],
              ),
              // Position marker — no rotation needed since map rotates with heading
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF)
                                  .withValues(alpha: 0.4),
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
                  ],
                ),
            ],
          ),
          ),

          // Top: Current maneuver card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _showManeuverList = !_showManeuverList),
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
                              // [Fix 2] Live countdown distance
                              Text(
                                _formatDistance(displayDist),
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
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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

          // Re-center button
          if (!_followUser)
            Positioned(
              right: 16,
              bottom: 100 + MediaQuery.of(context).padding.bottom,
              child: GestureDetector(
                onTap: () {
                  setState(() => _followUser = true);
                  if (_currentPosition != null) {
                    _mapController.moveAndRotate(
                      _currentPosition!,
                      16,
                      -_heading,
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.amber,
                    size: 24,
                  ),
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
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom bar
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
                  GestureDetector(
                    onTap: () => _showFeedbackAndExit(arrived: false),
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
