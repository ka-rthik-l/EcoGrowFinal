/// Toggle between local dev server and Render deployment.
///
/// Change [_current] to switch environments:
///   ApiEnvironment.local  → http://10.0.2.2:8000  (Android emulator)
///   ApiEnvironment.render → your Render URL
enum ApiEnvironment { local, render }

class ApiConfig {
  // ──────────────────────────────────────────────
  //  ↓ Change this value to switch environments ↓
  // ──────────────────────────────────────────────
  static const ApiEnvironment _current = ApiEnvironment.render;

  static const Map<ApiEnvironment, String> _urls = {
    ApiEnvironment.local: 'http://localhost:8000',
    ApiEnvironment.render: 'https://eco-grow-full.onrender.com',
  };

  static String get baseUrl => _urls[_current]!;
}
