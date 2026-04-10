import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RoundTripConfig {
  final double durationHours;
  final double heading;
  final int curvinessLevel;

  const RoundTripConfig({
    this.durationHours = 2.0,
    this.heading = 180,
    this.curvinessLevel = 2,
  });
}

class RoundTripSheet extends StatefulWidget {
  const RoundTripSheet({super.key});

  @override
  State<RoundTripSheet> createState() => _RoundTripSheetState();
}

class _RoundTripSheetState extends State<RoundTripSheet> {
  double _duration = 2.0;
  int _headingIndex = 4; // S
  int _curvinessLevel = 2;

  static const _directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  static const _headings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];

  String get _durationLabel {
    final h = _duration.floor();
    final m = ((_duration - h) * 60).round();
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Rundtour', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('Eine Runde fahren und zurückkommen', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),

              // Duration
              _SectionLabel(icon: Icons.timer_outlined, label: 'Dauer', value: _durationLabel),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0]) ...[
                    if (d != 0.5) const SizedBox(width: 5),
                    _DurationChip(
                      label: d < 1 ? '30m' : d == d.roundToDouble() ? '${d.round()}h' : '${d}h',
                      isActive: _duration == d,
                      onTap: () => setState(() => _duration = d),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Direction – compass
              _SectionLabel(
                icon: Icons.explore_outlined,
                label: 'Richtung',
                value: _directions[_headingIndex],
              ),
              const SizedBox(height: 12),
              _CompassSelector(
                selectedIndex: _headingIndex,
                onChanged: (i) => setState(() => _headingIndex = i),
              ),
              const SizedBox(height: 20),

              // Route style
              _SectionLabel(icon: Icons.turn_slight_right_rounded, label: 'Routenstil', value: ''),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StyleBtn(label: 'Schnell', isActive: _curvinessLevel == 0, onTap: () => setState(() => _curvinessLevel = 0)),
                  const SizedBox(width: 5),
                  _StyleBtn(label: 'Ausgewogen', isActive: _curvinessLevel == 1, onTap: () => setState(() => _curvinessLevel = 1)),
                  const SizedBox(width: 5),
                  _StyleBtn(label: 'Kurvig', isActive: _curvinessLevel == 2, onTap: () => setState(() => _curvinessLevel = 2)),
                  const SizedBox(width: 5),
                  _StyleBtn(label: 'Extrem', isActive: _curvinessLevel == 3, onTap: () => setState(() => _curvinessLevel = 3)),
                ],
              ),
              const SizedBox(height: 24),

              // Generate
              GestureDetector(
                onTap: () => Navigator.of(context).pop(
                  RoundTripConfig(
                    durationHours: _duration,
                    heading: _headings[_headingIndex],
                    curvinessLevel: _curvinessLevel,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Route generieren',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
        if (value.isNotEmpty) ...[
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.amber)),
        ],
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.amber.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: AppColors.amber.withValues(alpha: 0.4)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.amber : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassSelector extends StatelessWidget {
  const _CompassSelector({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 160,
      child: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Circle
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 2,
                  ),
                ),
              ),
              // Direction indicator line
              Transform.rotate(
                angle: (selectedIndex * 45) * pi / 180,
                child: Container(
                  width: 3,
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 60),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Center dot
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              // Direction buttons
              for (int i = 0; i < 8; i++)
                _CompassPoint(
                  label: _labels[i],
                  angle: i * 45.0,
                  isSelected: selectedIndex == i,
                  onTap: () => onChanged(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassPoint extends StatelessWidget {
  const _CompassPoint({
    required this.label,
    required this.angle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final double angle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radians = (angle - 90) * pi / 180;
    final radius = 68.0;

    return Positioned(
      left: 80 + radius * cos(radians) - 16,
      top: 80 + radius * sin(radians) - 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.amber
                : Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              if (isSelected)
                BoxShadow(color: AppColors.amber.withValues(alpha: 0.3), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label.length > 1 ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleBtn extends StatelessWidget {
  const _StyleBtn({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.amber.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: AppColors.amber.withValues(alpha: 0.4)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.amber : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
