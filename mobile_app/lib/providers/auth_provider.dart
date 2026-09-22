import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_service.dart';

class AuthState {
  final String? baseUrl;
  final String? apiKey;
  final String? email;
  final bool isLoaded;

  const AuthState({
    this.baseUrl,
    this.apiKey,
    this.email,
    this.isLoaded = false,
  });

  bool get isConnected =>
      (baseUrl?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false);

  AuthState copyWith({
    String? baseUrl,
    String? apiKey,
    String? email,
    bool? isLoaded,
  }) {
    return AuthState(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      email: email ?? this.email,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    load();
  }

  Future<void> load() async {
    final auth = AuthService.instance;
    await auth.load();
    state = AuthState(
      baseUrl: auth.baseUrl,
      apiKey: auth.apiKey,
      email: auth.email,
      isLoaded: true,
    );
  }

  Future<void> saveConnection({
    required String baseUrl,
    required String apiKey,
    required String email,
  }) async {
    await AuthService.instance.saveConnection(
      baseUrl: baseUrl,
      apiKey: apiKey,
      email: email,
    );
    state = AuthState(
      baseUrl: baseUrl,
      apiKey: apiKey,
      email: email,
      isLoaded: true,
    );
  }

  Future<void> notifyChanged() async {
    final auth = AuthService.instance;
    state = AuthState(
      baseUrl: auth.baseUrl,
      apiKey: auth.apiKey,
      email: auth.email,
      isLoaded: true,
    );
  }

  Future<void> disconnect() async {
    await AuthService.instance.disconnect();
    state = AuthState(
      baseUrl: AuthService.instance.baseUrl,
      apiKey: null,
      email: null,
      isLoaded: true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
