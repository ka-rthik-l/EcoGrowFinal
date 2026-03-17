import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  // ── Singleton ──────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'jwt_access_token';

  // ── Initialisation ─────────────────────────────
  static Future<void> init() async {
    final instance = ApiService();
    instance._dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Attach JWT token to every request automatically
    instance._dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await instance._storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  // ── Auth ───────────────────────────────────────

  /// Register a new user. Throws on failure.
  Future<void> register(String email, String password) async {
    await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  /// Login and store the JWT token. Returns the token. Throws on failure.
  Future<String> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/jwt/login',
      data: 'username=$email&password=$password',
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final token = response.data['access_token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  /// Clear the stored JWT token.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check whether a token is already stored.
  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ── Protected Data ─────────────────────────────

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _dio.get('/api/v1/dashboard');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnalysis() async {
    final response = await _dio.get('/api/v1/analysis');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTrends(String range) async {
    final response = await _dio.get(
      '/api/v1/trends',
      queryParameters: {'range': range},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAlerts() async {
    final response = await _dio.get('/api/v1/alerts');
    return response.data as List<dynamic>;
  }
}
