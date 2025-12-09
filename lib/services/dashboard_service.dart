// lib/services/dashboard_service.dart

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/dashboard_models.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class DashboardService {
  final AuthService _authService;
  final Dio _dio;

  DashboardService(this._authService) : _dio = _authService.dio;

  Future<DashboardData> fetchDashboardData({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 5, // Par défaut 5 (pour le dashboard), modifiable pour la liste complète
  }) async {
    try {
      final String startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final String endStr = DateFormat('yyyy-MM-dd').format(endDate);

      final response = await _dio.get('/dashboard/stats', queryParameters: {
        'startDate': startStr,
        'endDate': endStr,
        'limit': limit, // On passe la limite au backend
      });

      return DashboardData.fromJson(response.data);
      
    } on DioException catch (e) {
      debugPrint('DashboardService Error: ${e.response?.statusCode} - ${e.message}');
      throw Exception(e.response?.data['message'] ?? 'Erreur de connexion au serveur.');
    } catch (e) {
      debugPrint('DashboardService Unknown Error: $e');
      throw Exception('Impossible de charger le tableau de bord.');
    }
  }
}