// lib/services/report_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:wink_manager/models/report_models.dart';
import 'package:wink_manager/services/auth_service.dart';

class ReportService {
  final AuthService _authService;
  final Dio _dio;

  ReportService(this._authService) : _dio = _authService.dio;

  /// 1. Récupère la liste des bilans journaliers pour une date.
  Future<List<ReportSummary>> fetchReports(DateTime date) async {
    try {
      final response = await _dio.get(
        '/reports',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );

      if (response.data is List) {
        final List<dynamic> body = response.data;
        return body
            .map((dynamic item) => ReportSummary.fromJson(item))
            .toList();
      } else {
        debugPrint(
            'ReportService: fetchReports a reçu une réponse non-List: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) print('ReportService: Erreur fetchReports: $e');
      throw Exception(
          e.response?.data['message'] ?? 'Erreur réseau (Rapports)');
    }
  }

  /// 2. Récupère les détails complets d'un bilan pour l'action "Copier".
  Future<ReportDetailed> fetchReportDetails(
      DateTime date, int shopId) async {
    try {
      final response = await _dio.get(
        '/reports/detailed',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(date),
          'shopId': shopId,
        },
      );

      return ReportDetailed.fromJson(response.data);
    } on DioException catch (e) {
      if (kDebugMode) print('ReportService: Erreur fetchReportDetails: $e');
      throw Exception(
          e.response?.data['message'] ?? 'Erreur réseau (Détails Rapport)');
    }
  }

  /// 3. Déclenche le traitement des frais de stockage pour une date.
  Future<String> processStorage(DateTime date) async {
    try {
      final response = await _dio.post(
        '/reports/process-storage',
        data: {'date': DateFormat('yyyy-MM-dd').format(date)},
      );
      return response.data['message'] as String? ??
          'Traitement du stockage terminé.';
    } on DioException catch (e) {
      if (kDebugMode) print('ReportService: Erreur processStorage: $e');
      throw Exception(
          e.response?.data['message'] ?? 'Erreur (Traitement Stockage)');
    }
  }

  /// 4. Déclenche le recalcul des bilans pour une date.
  Future<String> recalculateReports(DateTime date) async {
    try {
      final response = await _dio.post(
        '/reports/recalculate-report',
        data: {'date': DateFormat('yyyy-MM-dd').format(date)},
      );
      return response.data['message'] as String? ?? 'Recalcul terminé.';
    } on DioException catch (e) {
      if (kDebugMode) print('ReportService: Erreur recalculateReports: $e');
      throw Exception(e.response?.data['message'] ?? 'Erreur (Recalcul)');
    }
  }
}