import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    widget.onComplete();
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _requestLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Move to next page regardless of result
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                // Page 1: Welcome
                _OnboardingPage(
                  icon: null,
                  useAssetImage: true,
                  title: 'PeakMoto',
                  subtitle: 'Kostenlos. Open Source.\nFür immer.',
                  description:
                      'Die einzige Motorrad-Navi-App ohne Abo,\nohne Account, ohne Tracking.',
                ),
                // Page 2: GPS
                _OnboardingPage(
                  icon: Icons.my_location_rounded,
                  title: 'Standort',
                  subtitle: 'Für Navigation & Routing',
                  description:
                      'PeakMoto braucht deinen Standort um dir\nden Weg zu zeigen. Deine Daten bleiben\nauf deinem Gerät.',
                ),
                // Page 3: Ride
                _OnboardingPage(
                  icon: Icons.route_rounded,
                  title: 'Ride the Curves',
                  subtitle: 'Kurvige Strecken bevorzugt',
                  description:
                      'Wähle zwischen Schnell, Ausgewogen,\nKurvig und Extrem.\nPeakMoto findet die besten Landstraßen.',
                ),
              ],
            ),
          ),

          // Dots + Button
          Padding(
            padding: EdgeInsets.only(
              left: 32,
              right: 32,
              bottom: bottomPadding + 32,
            ),
            child: Column(
              children: [
                // Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.amber
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // Action button
                GestureDetector(
                  onTap: () {
                    if (_currentPage == 0) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else if (_currentPage == 1) {
                      _requestLocation();
                    } else {
                      _finish();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _currentPage == 0
                          ? 'Weiter'
                          : _currentPage == 1
                              ? 'Standort erlauben'
                              : 'Los geht\'s',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                // Legal footer on welcome page
                if (_currentPage == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: 'Mit "Weiter" akzeptierst du unsere\n'),
                          TextSpan(
                            text: 'Datenschutzerklärung',
                            style: const TextStyle(
                              color: AppColors.amber,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openLegal(AppConstants.privacyUrl),
                          ),
                          const TextSpan(text: ' und '),
                          TextSpan(
                            text: 'Nutzungsbedingungen',
                            style: const TextStyle(
                              color: AppColors.amber,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openLegal(AppConstants.termsUrl),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                if (_currentPage == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(
                        'Später',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    this.icon,
    this.useAssetImage = false,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final IconData? icon;
  final bool useAssetImage;
  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(top: topPadding + 60, left: 32, right: 32),
      child: Column(
        children: [
          if (useAssetImage)
            Image.asset(
              'assets/icon-512.png',
              width: 120,
              height: 120,
            )
          else if (icon != null)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.amber),
            ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.amber,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
