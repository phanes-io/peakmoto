class AppConstants {
  AppConstants._();

  static const appName = 'PeakMoto';
  static const appVersion = '0.1.0';

  // Default tile server (OSM fallback until own tiles are ready)
  static const tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // BRouter API (self-hosted)
  static const brouterBaseUrl = 'https://brouter.peakmoto.app';

  // Nominatim (self-hosted)
  static const nominatimBaseUrl = 'https://nominatim.peakmoto.app';

  // Default map center (Germany)
  static const defaultLat = 48.7758;
  static const defaultLng = 9.1829; // Stuttgart

  // Touch targets for glove-friendly UI
  static const minTouchTarget = 64.0;
}
