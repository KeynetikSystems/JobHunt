import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const defaultBackendUrl = 'https://api.keynetiksystems.com';
  static const _baseUrlKey = 'backend_base_url';
  static const _apiKeyKey = 'backend_api_key';
  static const _emailKey = 'backend_email';

  static final AuthService instance = AuthService._();
  AuthService._();

  String? baseUrl;
  String? apiKey;
  String? email;

  bool get isConnected =>
      (baseUrl?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey) ?? defaultBackendUrl;
    apiKey = prefs.getString(_apiKeyKey);
    email = prefs.getString(_emailKey);
  }

  Future<void> saveConnection({
    required String baseUrl,
    required String apiKey,
    required String email,
  }) async {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.email = email;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
    await prefs.setString(_apiKeyKey, apiKey);
    await prefs.setString(_emailKey, email);
  }

  Future<void> disconnect() async {
    baseUrl = defaultBackendUrl;
    apiKey = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_emailKey);
  }
}
