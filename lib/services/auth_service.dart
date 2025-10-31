import 'dart:convert';
import 'package:dio/dio.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:wink_manager/models/user.dart'; 

class AuthService extends ChangeNotifier {
  // CORRECTION : Utilisation de l'URL de production
  static const String _apiBaseUrl = "https://app.winkexpress.online/api";
  static const String _userKey = "currentUser";

  final Dio _dio = Dio();
  
  User? _user;
  bool _isLoading = false;

  User? get user => _user; 
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  Dio get dio => _dio; // Exposé pour les autres services
  String? get token => _user?.token;

  AuthService() {
    // CORRECTION CRITIQUE : Définir la Base URL ici
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

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      _user = User.fromJson(jsonDecode(userJson));
      if (_user!.role != 'admin') {
        await logout(); 
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String phoneNumber, String pin, {required bool rememberMe}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.post(
        '/login', // Utilise la Base URL
        data: { 'phoneNumber': phoneNumber, 'pin': pin },
      );

      final userData = response.data['user'];
      final user = User.fromJson(userData);

      if (user.role != 'admin') {
        throw Exception("Accès refusé : Seuls les admins sont autorisés.");
      }

      _user = user;

      if (rememberMe) { 
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
      }
      
    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Erreur de connexion inconnue.';
      throw Exception(message);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners(); 
  }
}