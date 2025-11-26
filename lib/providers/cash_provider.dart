// lib/providers/cash_provider.dart

import 'package:flutter/foundation.dart';
import 'package:wink_manager/models/cash_models.dart';
import 'package:wink_manager/models/user.dart'; // Import du modèle User
import 'package:wink_manager/repositories/cash_repository.dart';
import 'package:wink_manager/providers/network_provider.dart';

class CashProvider with ChangeNotifier {
  // --- MODIFIÉ : Retrait de 'final' pour permettre la mise à jour ---
  CashRepository _repository;
  final NetworkProvider _networkProvider;
  
  // --- MODIFIÉ : Variable _kItemsPerPage supprimée car inutilisée ---

  // --- État de la liste et des données ---
  CashMetrics _metrics = CashMetrics();
  List<RemittanceSummaryItem> _remittanceSummary = []; 
  List<CashTransaction> _transactions = []; 
  List<Shortfall> _shortfalls = [];
  List<ExpenseCategory> _categories = [];
  List<CashClosing> _closingHistory = []; 

  // Détails versement & Sélection
  List<RemittanceOrder> _currentRemittanceOrders = [];
  Set<int> _selectedOrderIds = {}; 

  // Filtres globaux
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int _currentTabIndex = 1; 
  String _searchQuery = ''; // Recherche globale

  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  CashMetrics get metrics => _metrics;
  List<RemittanceSummaryItem> get remittanceSummary => _remittanceSummary;
  List<CashTransaction> get transactions => _transactions;
  List<Shortfall> get shortfalls => _shortfalls;
  List<ExpenseCategory> get categories => _categories;
  List<CashClosing> get closingHistory => _closingHistory;
  
  // Alias pour compatibilité UI
  List<RemittanceOrder> get remittanceDetails => _currentRemittanceOrders; 
  List<RemittanceOrder> get currentRemittanceOrders => _currentRemittanceOrders;
  
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get searchQuery => _searchQuery;

  Set<int> get selectedOrderIds => _selectedOrderIds;
  
  // Calcul du total sélectionné pour confirmation (Versements)
  double get totalSelectedAmount {
    double total = 0;
    for (var order in _currentRemittanceOrders) {
      if (_selectedOrderIds.contains(order.orderId)) {
        total += order.expectedAmount;
      }
    }
    return total;
  }

  // --- NOUVEAUX GETTERS POUR LE FILTRAGE DYNAMIQUE ---
  // Ces getters calculent la somme des éléments ACTUELLEMENT chargés dans la liste _transactions.
  // Si _transactions est filtré par "taxi", cela donnera le total des taxis.

  double get filteredExpensesTotal {
    if (_transactions.isEmpty) return 0.0;
    return _transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount.abs()); // On utilise abs() car stocké en négatif
  }

  double get filteredWithdrawalsTotal {
    if (_transactions.isEmpty) return 0.0;
    return _transactions
        .where((t) => t.type == 'manual_withdrawal' || t.type == 'withdrawal')
        .fold(0.0, (sum, t) => sum + t.amount.abs());
  }
  // ---------------------------------------------------

  // --- Constructeur & Update ---

  CashProvider(this._repository, this._networkProvider) {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _networkProvider.addListener(_onNetworkChange);
  }

  void update(CashRepository repo) {
    _repository = repo;
  }

  @override
  void dispose() {
    _networkProvider.removeListener(_onNetworkChange);
    super.dispose();
  }

  void _onNetworkChange() {
    if (_networkProvider.isOnline) {
      loadData();
    }
  }

  // --- Gestion des Filtres ---

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end.copyWith(hour: 23, minute: 59, second: 59);
    loadData();
  }

  void setTabIndex(int index) {
    _currentTabIndex = index;
    // On vide la recherche quand on change d'onglet pour éviter les confusions
    _searchQuery = ''; 
    loadData();
  }

  void setSearch(String query) {
    _searchQuery = query;
    loadData();
  }

  // --- Chargement des Données ---

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Toujours charger les métriques globales (Bilan Comptable)
      // Ces métriques NE SONT PAS affectées par la recherche locale (c'est voulu).
      _metrics = await _repository.fetchMetrics(_startDate, _endDate);

      // 2. Charger les données spécifiques à l'onglet actif avec le filtre de recherche
      if (_currentTabIndex == 1) { 
        // Versements
        _remittanceSummary = await _repository.fetchRemittanceSummary(
          startDate: _startDate, endDate: _endDate
        );
        // Filtrage local simple pour le résumé si recherche active (si non géré par l'API)
        if (_searchQuery.isNotEmpty) {
           _remittanceSummary = _remittanceSummary.where((item) => 
              item.userName.toLowerCase().contains(_searchQuery.toLowerCase())
           ).toList();
        }
      } 
      else if (_currentTabIndex == 2) { 
        // Opérations (Dépenses/Décaissements)
        // Ici, le repository envoie le paramètre 'search' à l'API
        _transactions = await _repository.fetchTransactions(
          startDate: _startDate, 
          endDate: _endDate,
          search: _searchQuery // Le backend filtre les résultats
        );
        
        // Charger les catégories si nécessaire
        if (_categories.isEmpty) {
          _categories = await _repository.fetchCategories();
        }
      } 
      else if (_currentTabIndex == 3) { 
        // Manquants
        // Ici aussi on peut filtrer
        _shortfalls = await _repository.fetchShortfalls(search: _searchQuery);
      }
      
      // Charger l'historique pour l'écran de clôture
      _closingHistory = await _repository.fetchClosingHistory(_startDate, _endDate);

    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Gestion des Détails de Versement ---

  Future<void> loadRemittanceDetails(int deliverymanId) async {
    _isLoading = true;
    _currentRemittanceOrders = [];
    _selectedOrderIds.clear(); 
    notifyListeners();

    try {
      final result = await _repository.fetchRemittanceDetails(deliverymanId, _startDate, _endDate);
      _currentRemittanceOrders = result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void toggleOrderSelection(int orderId) {
    if (_selectedOrderIds.contains(orderId)) {
      _selectedOrderIds.remove(orderId);
    } else {
      _selectedOrderIds.add(orderId);
    }
    notifyListeners();
  }

  void selectAllOrders(bool select) {
    if (select) {
      _selectedOrderIds = _currentRemittanceOrders
          .where((o) => o.status != 'confirmed')
          .map((o) => o.orderId)
          .toSet();
    } else {
      _selectedOrderIds.clear();
    }
    notifyListeners();
  }

  // --- Recherche Utilisateur (Autocomplete) ---
  
  Future<List<User>> searchUsers(String query) async {
    try {
      return await _repository.searchUsers(query);
    } catch (e) {
      if (kDebugMode) print("Erreur recherche users: $e");
      return [];
    }
  }

  // --- Actions CRUD : Opérations (Dépenses / Décaissements) ---

  Future<void> addExpense(int userId, int categoryId, double amount, String comment, DateTime date) async {
    try {
      await _repository.createExpense({
        'user_id': userId,
        'category_id': categoryId,
        'amount': amount,
        'comment': comment,
        'created_at': date.toIso8601String(), 
      });
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addWithdrawal(double amount, String comment, int userId, DateTime date) async {
    try {
      await _repository.createWithdrawal({
        'amount': amount,
        'comment': comment,
        'user_id': userId,
        'created_at': date.toIso8601String(),
      });
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTransaction(int id, double amount, String comment) async {
    try {
      await _repository.updateTransaction(id, amount, comment);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  // --- Actions CRUD : Manquants (Shortfalls) ---

  Future<void> createShortfall(int deliverymanId, double amount, String comment, DateTime date) async {
    try {
      await _repository.createShortfall(deliverymanId, amount, comment, date);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateShortfall(int id, double amount, String comment) async {
    try {
      await _repository.updateShortfall(id, amount, comment);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteShortfall(int id) async {
    try {
      await _repository.deleteShortfall(id);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> settleShortfall(int id, double amount) async {
    try {
      await _repository.settleShortfall(id, amount, DateTime.now());
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  // --- Actions : Versements & Clôture ---

  Future<void> confirmRemittance(int deliverymanId) async {
    try {
      if (_selectedOrderIds.isEmpty) return;
      
      await _repository.confirmRemittance(
        deliverymanId: deliverymanId,
        orderIds: _selectedOrderIds.toList(),
        amount: totalSelectedAmount,
        date: _endDate, 
      );
      
      await loadRemittanceDetails(deliverymanId);
      
      if (_currentTabIndex == 1) {
         // Mettre à jour le résumé et les métriques
         await loadData(); 
      }
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> performClosing(double actualCash, String comment, DateTime closingDate) async {
    try {
      await _repository.closeCash(closingDate, actualCash, comment);
      await loadData();
    } catch (e) {
      rethrow;
    }
  }
}