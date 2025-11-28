import 'package:dio/dio.dart'; 
import 'package:flutter/material.dart';
import 'package:wink_manager/models/user.dart'; 
// --- NOUVEAUX IMPORTS ---
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
// --- FIN DES NOUVEAUX IMPORTS ---

class AuthService extends ChangeNotifier {
  static const String _apiBaseUrl = "https://app.winkexpress.online/api";
  
  // --- MODIFIÉ : Ajout du stockage sécurisé ---
  static const String _userKey = "currentUser";
  final _storage = const FlutterSecureStorage();
  // --- FIN MODIFICATION ---

  final Dio _dio = Dio();
  
  User? _user;
  bool _isLoading = false; // Sera utilisé pour l'auto-login

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
    
    // On appelle tryAutoLogin au moment de l'initialisation du service
    tryAutoLogin();
  }

  // --- NOUVELLE MÉTHODE : Tente de connecter l'utilisateur au démarrage ---
  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userString = await _storage.read(key: _userKey);
      
      if (userString != null) {
        final Map<String, dynamic> userData = jsonDecode(userString);
        _user = User.fromJson(userData);
      }
    } catch (e) {
      // Si le décodage échoue, on ne fait rien (l'utilisateur n'est pas connecté)
      debugPrint('Erreur autoLogin: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // --- FIN NOUVELLE MÉTHODE ---

  // --- MODIFIÉ : Signature mise à jour pour inclure rememberMe ---
  Future<void> login(String phoneNumber, String pin, {required bool rememberMe}) async {
  // --- FIN MODIFICATION ---
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

      // --- MODIFIÉ : Logique de sauvegarde ---
      if (rememberMe) {
        // Sauvegarde sécurisée
        await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
      } else {
        // S'il ne veut pas se souvenir, on s'assure que rien n'est stocké
        await _storage.delete(key: _userKey);
      }
      // --- FIN MODIFICATION ---
      
    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? 'Erreur de connexion inconnue.';
      throw Exception(message);
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  // --- MODIFIÉ : Logique de suppression ---
  Future<void> logout() async {
    _user = null;
    // Supprime la session sauvegardée
    await _storage.delete(key: _userKey); 
    notifyListeners(); 
  }
  // --- FIN MODIFICATION ---
}