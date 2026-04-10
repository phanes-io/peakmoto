import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/constants.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

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
              Text(
                'Einstellungen',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),

              _SectionHeader('Darstellung'),
              _SettingsGroup(children: [
                _ThemeRow(
                  isDark: isDark,
                  onChanged: (dark) {
                    ref.read(themeModeProvider.notifier).state =
                        dark ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ]),

              const SizedBox(height: 24),
              _SectionHeader('Karte'),
              _SettingsGroup(children: [
                _SettingsRow(
                  icon: Icons.map_rounded,
                  label: 'Kartenstil',
                  trailing: 'Standard',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.download_rounded,
                  label: 'Offline-Karten',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),
              _SectionHeader('Navigation'),
              _SettingsGroup(children: [
                _SettingsRow(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Sprachansagen',
                  trailing: 'An',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.speed_rounded,
                  label: 'Geschwindigkeit',
                  trailing: 'km/h',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),
              _SectionHeader('Info'),
              _SettingsGroup(children: [
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Version',
                  trailing: AppConstants.appVersion,
                ),
                _SettingsRow(
                  icon: Icons.code_rounded,
                  label: 'Quellcode',
                  trailing: 'AGPL-3.0',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.amber,
                  label: 'PeakMoto unterstützen',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            size: 20,
            color: AppColors.amber,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dunkelmodus',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: -0.2,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            onChanged: onChanged,
            activeTrackColor: AppColors.amber,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Divider(
                  height: 0.5,
                  color: Theme.of(context).dividerColor,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? theme.textTheme.bodyMedium?.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.dividerColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
