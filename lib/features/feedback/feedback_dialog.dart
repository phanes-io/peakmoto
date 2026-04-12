import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Result returned from FeedbackDialog.
/// rating = 0 means skipped, 1-5 means user gave a rating.
class FeedbackResult {
  final int rating;
  final String? comment;

  const FeedbackResult({required this.rating, this.comment});
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({
    super.key,
    required this.distanceKm,
    required this.durationMin,
    required this.turnCount,
    required this.arrived,
  });

  final double distanceKm;
  final int durationMin;
  final int turnCount;
  final bool arrived;

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  int _rating = 0;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDistance() {
    if (widget.distanceKm >= 100) return '${widget.distanceKm.round()} km';
    if (widget.distanceKm >= 1) {
      return '${widget.distanceKm.toStringAsFixed(1)} km';
    }
    return '${(widget.distanceKm * 1000).round()} m';
  }

  String _formatDuration() {
    final h = widget.durationMin ~/ 60;
    final m = widget.durationMin % 60;
    if (h > 0) return '${h}h ${m}min';
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.arrived ? 'Ziel erreicht 🏁' : 'Route beendet';

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _StatChip(icon: Icons.straighten_rounded, value: _formatDistance()),
                const SizedBox(width: 12),
                _StatChip(icon: Icons.timer_outlined, value: _formatDuration()),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.turn_right_rounded,
                  value: '${widget.turnCount}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Wie war die Route?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // 5 star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? AppColors.amber
                          : theme.textTheme.bodyMedium?.color,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Comment field
            TextField(
              controller: _controller,
              maxLength: 300,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Kommentar (optional)',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(
                      const FeedbackResult(rating: 0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Überspringen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(
                        FeedbackResult(
                          rating: _rating,
                          comment: _controller.text.trim().isEmpty
                              ? null
                              : _controller.text.trim(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _rating > 0
                            ? AppColors.amber
                            : AppColors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Senden',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

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
