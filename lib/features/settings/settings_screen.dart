import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSection('App', [
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.amber),
              title: const Text('Version'),
              subtitle: const Text(AppConstants.appVersion),
            ),
          ]),
          _buildSection('About', [
            ListTile(
              leading: const Icon(Icons.code, color: AppColors.amber),
              title: const Text('Source Code'),
              subtitle: const Text('AGPL-3.0 – Free & Open Source'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline, color: AppColors.amber),
              title: const Text('Support PeakMoto'),
              subtitle: const Text('Buy us a coffee on Ko-fi'),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
