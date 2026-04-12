import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import 'gpx_service.dart';
import 'saved_route.dart';
import 'saved_routes_provider.dart';

class SavedRoutesSheet extends ConsumerWidget {
  const SavedRoutesSheet({super.key, this.onLoadRoute});

  /// Called when user taps a saved route to load it on the map
  final void Function(SavedRoute route)? onLoadRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routes = ref.watch(savedRoutesProvider);
    final gpxService = GpxService();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Gespeicherte Routen', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    // Import GPX button
                    GestureDetector(
                      onTap: () => _importGpx(context, ref, gpxService),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_upload_rounded, color: AppColors.amber, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${routes.length}',
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Routes list or empty state
              Expanded(
                child: routes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_outline_rounded,
                              size: 56,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Noch keine Routen gespeichert',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Gespeicherte Routen erscheinen hier',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return _RouteItem(
                            route: route,
                            onTap: () {
                              Navigator.pop(context);
                              onLoadRoute?.call(route);
                            },
                            onShare: () => _exportGpx(context, gpxService, route),
                            onDelete: () {
                              ref.read(savedRoutesProvider.notifier).delete(route.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportGpx(BuildContext context, GpxService gpxService, SavedRoute route) async {
    final gpxString = gpxService.export(route);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${route.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.gpx');
    await file.writeAsString(gpxString);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _importGpx(BuildContext context, WidgetRef ref, GpxService gpxService) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final content = await file.readAsString();
    final route = gpxService.import(content);

    if (route != null) {
      await ref.read(savedRoutesProvider.notifier).save(route);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${route.name} importiert'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPX-Datei konnte nicht gelesen werden'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({
    required this.route,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  final SavedRoute route;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(route.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded, color: AppColors.amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route.distanceFormatted} · ${route.durationFormatted} · ${route.dateFormatted}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onShare,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.share_rounded, size: 18, color: theme.textTheme.bodyMedium?.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
