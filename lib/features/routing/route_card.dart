import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'routing_provider.dart';
import 'routing_service.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.routes,
    required this.selectedIndex,
    required this.destinationName,
    required this.prefs,
    required this.onPrefsChanged,
    required this.onRouteSelected,
    required this.onClose,
    required this.onStartNavigation,
  });

  final RouteResult route;
  final List<RouteResult> routes;
  final int selectedIndex;
  final String destinationName;
  final RoutePreferences prefs;
  final ValueChanged<RoutePreferences> onPrefsChanged;
  final ValueChanged<int> onRouteSelected;
  final VoidCallback onClose;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  destinationName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 20, color: theme.textTheme.bodyMedium?.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats
          Row(
            children: [
              _InfoChip(icon: Icons.straighten_rounded, value: route.distanceFormatted),
              const SizedBox(width: 16),
              _InfoChip(icon: Icons.timer_outlined, value: route.durationFormatted),
              if (route.ascentM > 0) ...[
                const SizedBox(width: 16),
                _InfoChip(icon: Icons.trending_up_rounded, value: route.ascentFormatted),
              ],
            ],
          ),
          // Route alternatives
          if (routes.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < routes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _RouteOption(
                      label: i == 0 ? 'Fastest' : 'Scenic ${i > 1 ? i : ''}',
                      distance: routes[i].distanceFormatted,
                      duration: routes[i].durationFormatted,
                      isActive: selectedIndex == i,
                      onTap: () => onRouteSelected(i),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Route style buttons
          Row(
            children: [
              _StyleButton(
                label: 'Fast',
                icon: Icons.speed_rounded,
                isActive: prefs.curvinessLevel == 0,
                onTap: () => onPrefsChanged(prefs.copyWith(curvinessLevel: 0)),
              ),
              const SizedBox(width: 5),
              _StyleButton(
                label: 'Balanced',
                icon: Icons.balance_rounded,
                isActive: prefs.curvinessLevel == 1,
                onTap: () => onPrefsChanged(prefs.copyWith(curvinessLevel: 1)),
              ),
              const SizedBox(width: 5),
              _StyleButton(
                label: 'Curvy',
                icon: Icons.turn_slight_right_rounded,
                isActive: prefs.curvinessLevel == 2,
                onTap: () => onPrefsChanged(prefs.copyWith(curvinessLevel: 2)),
              ),
              const SizedBox(width: 5),
              _StyleButton(
                label: 'Twisty',
                icon: Icons.all_inclusive_rounded,
                isActive: prefs.curvinessLevel == 3,
                onTap: () => onPrefsChanged(prefs.copyWith(curvinessLevel: 3)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Avoid toggles
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ToggleChip(
                label: 'Highways',
                icon: Icons.add_road_rounded,
                avoided: prefs.avoidHighways,
                onTap: () => onPrefsChanged(prefs.copyWith(avoidHighways: !prefs.avoidHighways)),
              ),
              _ToggleChip(
                label: 'Tolls',
                icon: Icons.toll_rounded,
                avoided: prefs.avoidTolls,
                onTap: () => onPrefsChanged(prefs.copyWith(avoidTolls: !prefs.avoidTolls)),
              ),
              _ToggleChip(
                label: 'Ferries',
                icon: Icons.directions_boat_rounded,
                avoided: prefs.avoidFerries,
                onTap: () => onPrefsChanged(prefs.copyWith(avoidFerries: !prefs.avoidFerries)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Start button
          GestureDetector(
            onTap: onStartNavigation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Start Navigation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
            border: isActive
                ? Border.all(color: AppColors.amber.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isActive ? AppColors.amber : theme.textTheme.bodyMedium?.color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppColors.amber : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.label,
    required this.distance,
    required this.duration,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String distance;
  final String duration;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.amber.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: AppColors.amber.withValues(alpha: 0.4))
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.amber : theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$distance · $duration',
              style: TextStyle(
                fontSize: 10,
                color: isActive
                    ? AppColors.amber.withValues(alpha: 0.7)
                    : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.avoided,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool avoided;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: avoided
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
              : AppColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: avoided
              ? null
              : Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: avoided ? theme.textTheme.bodyMedium?.color : AppColors.amber,
            ),
            const SizedBox(width: 5),
            Text(
              avoided ? 'No $label' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: avoided ? theme.textTheme.bodyMedium?.color : AppColors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteCardSkeleton extends StatelessWidget {
  const RouteCardSkeleton({super.key, required this.destinationName});

  final String destinationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shimmer = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  destinationName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SkeletonBox(width: 70, height: 16, color: shimmer),
              const SizedBox(width: 16),
              _SkeletonBox(width: 60, height: 16, color: shimmer),
            ],
          ),
          const SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 20, color: shimmer),
          const SizedBox(height: 10),
          Row(
            children: [
              _SkeletonBox(width: 80, height: 28, color: shimmer, radius: 8),
              const SizedBox(width: 8),
              _SkeletonBox(width: 80, height: 28, color: shimmer, radius: 8),
            ],
          ),
          const SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 48, color: shimmer, radius: 12),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.amber),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 6,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
