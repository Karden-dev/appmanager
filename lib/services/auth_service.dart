import 'package:dio/dio.dart'; 
import 'package:flutter/material.dart';
import 'package:wink_manager/models/user.dart'; 
// import 'package:shared_preferences/shared_preferences.dart'; // SUPPRIMÉ
// import 'dart:convert'; // SUPPRIMÉ

class AuthService extends ChangeNotifier {
  static const String _apiBaseUrl = "https://app.winkexpress.online/api";
  // static const String _userKey = "currentUser"; // SUPPRIMÉ

  final Dio _dio = Dio();
  
  User? _user;
  bool _isLoading = false;

  User? get user => _user; 
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  Dio get dio => _dio; 
  String? get token => _user?.token;

  AuthService() {
    _dio.options.baseUrl = _apiBaseUrl;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_user?.token != null) {
           options.headers["Authorization"] = "Bearer ${_user!.token}";
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          debugPrint('AuthService Interceptor: Token expiré. Déconnexion forcée.');
          await logout(); 
        }
        handler.next(e); 
      },
    ));
  }
  
  // get SharedPreferences => null; // SUPPRIMÉ

  // --- MÉTHODE tryAutoLogin SUPPRIMÉE ---

  // Signature simplifiée (plus de rememberMe)
  Future<void> login(String phoneNumber, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.post(
        '/login', 
        data: { 'phoneNumber': phoneNumber, 'pin': pin },
      );

      final userData = response.data['user'];
      final user = User.fromJson(userData);

      if (user.role != 'admin') {
        throw Exception("Accès refusé : Seuls les admins sont autorisés.");
      }

      _user = user;

      // --- BLOC if (rememberMe) SUPPRIMÉ ---
      
    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Erreur de connexion inconnue.';
      throw Exception(message);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  // Logique de SharedPreferences supprimée
  Future<void> logout() async {
    _user = null;
    // final prefs = await SharedPreferences.getInstance(); // SUPPRIMÉ
    // await prefs.remove(_userKey); // SUPPRIMÉ
    notifyListeners(); 
  }
}