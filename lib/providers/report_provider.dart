// lib/providers/report_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wink_manager/models/report_models.dart';
// *** IMPORTS MODIFIÉS ***
import 'package:wink_manager/repositories/report_repository.dart';
import 'package:wink_manager/providers/network_provider.dart';
// *** FIN IMPORTS MODIFIÉS ***


class ReportProvider with ChangeNotifier {
  // *** DÉPENDANCES MISES À JOUR ***
  final ReportRepository _reportRepository;
  final NetworkProvider _networkProvider;
  // *** FIN DÉPENDANCES ***

  // *** CONSTRUCTEUR MIS À JOUR ***
  ReportProvider(this._reportRepository, this._networkProvider) {
    // Écoute les changements de réseau pour rafraîchir
    _networkProvider.addListener(_onNetworkChange);
    // Charge les données initiales
    loadReports(forceApi: false);
  }

  // --- État (State) ---
  DateTime _selectedDate = DateTime.now();
  List<ReportSummary> _allReports = [];
  List<ReportSummary> _filteredReports = [];
  ReportStatCards? _statCards;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  
  final Set<int> _copiedShopIds = {};

  // --- Getters (Sélecteurs) ---
  DateTime get selectedDate => _selectedDate;
  List<ReportSummary> get filteredReports => _filteredReports;
  ReportStatCards? get statCards => _statCards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  Set<int> get copiedShopIds => _copiedShopIds;

  @override
  void dispose() {
    _networkProvider.removeListener(_onNetworkChange);
    super.dispose();
  }

  void _onNetworkChange() {
    // Si on revient en ligne, rafraîchir les données
    if (_networkProvider.isOnline) {
      loadReports(forceApi: true);
    }
  }

  /// Charge (ou recharge) les bilans pour la date sélectionnée.
  Future<void> loadReports({bool forceApi = false}) async {
    // Ne recharge pas si on force l'API alors qu'on est offline
    if (forceApi && !_networkProvider.isOnline) return;

    _isLoading = true;
    _error = null;
    
    if (_allReports.isEmpty) {
      notifyListeners();
    }
    
    try {
      // Appelle le Repository, qui gère le cache/l'API
      final reports = await _reportRepository.fetchReports(_selectedDate);
      _allReports = reports;
      
      _calculateStats(); 
      _applySearchFilter(); 

    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _allReports = [];
      _filteredReports = [];
      _statCards = ReportStatCards();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour la date sélectionnée et recharge les données.
  Future<void> setDate(DateTime newDate) async {
    if (newDate.year == _selectedDate.year &&
        newDate.month == _selectedDate.month &&
        newDate.day == _selectedDate.day) {
      return;
    }
    _selectedDate = newDate;
    _searchQuery = ''; 
    _copiedShopIds.clear(); 

    notifyListeners(); 
    await loadReports(forceApi: false); // Charge depuis cache/API
  }

  /// Met à jour le filtre de recherche et applique le filtre.
  void setSearch(String query) {
    _searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  /// Déclenche le traitement des frais de stockage pour la date en cours.
  Future<String> triggerProcessStorage() async {
    _isLoading = true;
    notifyListeners();
    String message;
    try {
      message = await _reportRepository.processStorage(_selectedDate);
      await loadReports(forceApi: true); 
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      message = _error!;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    return message;
  }

  /// Déclenche le recalcul des bilans pour la date en cours.
  Future<String> triggerRecalculate() async {
    _isLoading = true;
    notifyListeners();
    String message;
    try {
      message = await _reportRepository.recalculateReports(_selectedDate);
      await loadReports(forceApi: true); 
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      message = _error!;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    return message;
  }

  /// Génère le texte à copier (délégué au Repository).
  Future<String> generateReportStringForCopy(int shopId) async {
    try {
      // Le provider passe l'état du réseau au repository
      final reportString = await _reportRepository.generateReportStringForCopy(
          _selectedDate, shopId, _networkProvider.isOnline);

      await Clipboard.setData(ClipboardData(text: reportString));

      _copiedShopIds.add(shopId);
      notifyListeners(); 

      // Trouve le nom du magasin pour le message de succès
      final shopName = _allReports.firstWhere((r) => r.shopId == shopId).shopName;
      return 'Le rapport détaillé pour "$shopName" a été copié !';

    } catch (e) {
      if (kDebugMode) print("Erreur generateReportStringForCopy: $e");
      throw Exception(e.toString().replaceFirst('Exception: ', 'Erreur copie: '));
    }
  }


  // --- Logique privée (State/UI) ---

  /// Calcule les 4 cartes de statistiques (inchangé).
  void _calculateStats() {
    double totalDebt = 0;
    double totalPackaging = 0;
    double totalStorage = 0;
    int activeMerchantsCount = 0;
    double totalRemit = 0;

    for (final report in _allReports) {
      if (report.amountToRemit == -100) continue; // Filtre strict
      
      if (report.totalOrdersSent > 0) {
        activeMerchantsCount++;
      }
      totalPackaging += report.totalPackagingFees;
      totalStorage += report.totalStorageFees;
      totalRemit += report.amountToRemit;

      final amountToRemit = report.amountToRemit;
      if (amountToRemit < 0) {
        totalDebt += amountToRemit.abs();
      }
    }

    _statCards = ReportStatCards(
      activeMerchants: activeMerchantsCount,
      totalPackaging: totalPackaging,
      totalStorage: totalStorage,
      totalDebt: totalDebt,
      totalAmountToRemit: totalRemit,
    );
  }

  /// Filtre la liste (inchangé).
  void _applySearchFilter() {
    List<ReportSummary> tempReports;
    
    // 1. Appliquer le filtre -100
    tempReports = _allReports
        .where((report) => report.amountToRemit != -100)
        .toList();

    // 2. Appliquer le filtre de recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      tempReports = tempReports
          .where((report) =>
              report.shopName.toLowerCase().contains(query))
          .toList();
    }
    
    // 3. Tri par nom
    tempReports.sort((a, b) => a.shopName.compareTo(b.shopName));
    
    _filteredReports = tempReports;
  }
}