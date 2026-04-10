class AppConstants {
  AppConstants._();

  static const appName = 'PeakMoto';
  static const appVersion = '0.1.0';

  // Map tiles – clean grayscale basemaps
  static const tileUrlDark =
      'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const tileUrlLight =
      'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  // GraphHopper Routing API (self-hosted)
  static const routingBaseUrl = 'https://routing.peakmoto.app';

  // Photon Geocoding (self-hosted, fallback to komoot)
  static const photonHost = 'photon.peakmoto.app';

  // Default map center / Desktop fallback GPS
  static const defaultLat = 51.7640;
  static const defaultLng = 8.7340; // Marienloh, Paderborn

  // Touch targets for glove-friendly UI
  static const minTouchTarget = 64.0;
}
