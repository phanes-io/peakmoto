import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'routing_provider.dart';

class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.waypoints,
    required this.onAddStop,
    required this.onTapWaypoint,
    required this.onRemoveWaypoint,
    required this.onClose,
  });

  final List<Waypoint> waypoints;
  final VoidCallback onAddStop;
  final ValueChanged<int> onTapWaypoint;
  final ValueChanged<int> onRemoveWaypoint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
        children: [
          for (int i = 0; i < waypoints.length; i++) ...[
            if (i > 0) _AddStopRow(onTap: onAddStop),
            _WaypointRow(
              waypoint: waypoints[i],
              index: i,
              isFirst: i == 0,
              isLast: i == waypoints.length - 1,
              canRemove: waypoints.length > 2 && i > 0 && i < waypoints.length - 1,
              onRemove: () => onRemoveWaypoint(i),
              onTap: () => onTapWaypoint(i),
              onClose: i == 0 ? onClose : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({
    required this.waypoint,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.canRemove,
    required this.onRemove,
    required this.onTap,
    this.onClose,
  });

  final Waypoint waypoint;
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Dot indicator
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Container(
              width: isFirst ? 10 : isLast ? 12 : 8,
              height: isFirst ? 10 : isLast ? 12 : 8,
              decoration: BoxDecoration(
                color: isFirst
                    ? const Color(0xFF34C759)
                    : isLast
                        ? AppColors.amber
                        : AppColors.amberDark,
                shape: isLast ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isLast ? BorderRadius.circular(2) : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              waypoint.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Remove or close button
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: theme.textTheme.bodyMedium?.color),
              ),
            )
          else if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: theme.textTheme.bodyMedium?.color),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddStopRow extends StatelessWidget {
  const _AddStopRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 2,
                      height: 3,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      color: theme.dividerColor,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.amber.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              'Stopp hinzufügen',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.amber.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
