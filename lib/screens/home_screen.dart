// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/websocket_service.dart';
import '../utils/app_theme.dart';

// --- IMPORTS DES ÉCRANS MIGRÉS ---
import 'orders_today_screen.dart';
import 'orders_history_screen.dart';
import 'orders_relaunch_screen.dart';
import 'riders_returns_screen.dart';
import 'rider_cash_screen.dart';
import 'rider_performance_screen.dart';
// --- NOUVEAU IMPORT ---
import 'global_chat_list_screen.dart'; // <-- AJOUTÉ

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> _counts = {};
  bool _isLoadingCounts = true;
  int _selectedIndex = 0;

  StreamSubscription? _eventSubscription;

  final List<Widget> _widgetOptions = <Widget>[
    const OrdersTodayScreen(),
    const OrdersHistoryScreen(),
    const RiderCashScreen(),
    const RiderPerformanceScreen(),
  ];

  final List<String> _titles = <String>[
    'Courses du Jour',
    'Mes Courses (Historique)',
    'Ma Caisse',
    'Mes Performances',
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCounts();
      _setupWebSocketListener();
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupWebSocketListener() {
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService?>(context, listen: false);
    if (wsService == null) return;

    _eventSubscription?.cancel();

    _eventSubscription = wsService.eventStream.listen((event) {
      if (event == 'ORDER_UPDATE' || event == 'UNREAD_COUNT_UPDATE' || event == 'REMITTANCE_UPDATE') {
        _fetchCounts();
      }
    });
  }


  Future<void> _fetchCounts() async {
    if (!mounted) return;
    final orderService = Provider.of<OrderService?>(context, listen: false);

    if (orderService != null) {
      try {
        final counts = await orderService.fetchOrderCounts();
        if (mounted) {
          setState(() {
            _counts = counts;
            _isLoadingCounts = false;
          });
        }
      } catch (e) {
         if (mounted) {
            setState(() { _isLoadingCounts = false; });
         }
        debugPrint('Erreur chargement compteurs: $e');
      }
    } else {
        if (mounted) {
          setState(() { _isLoadingCounts = false; });
        }
    }
  }

  int get _todayTotal {
    if (_counts.isEmpty && _isLoadingCounts) return 0;
    return (_counts['pending'] ?? 0) +
           (_counts['in_progress'] ?? 0) +
           (_counts['ready_for_pickup'] ?? 0) +
           (_counts['en_route'] ?? 0) +
           (_counts['reported'] ?? 0);
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
    _fetchCounts();
  }


  @override
  Widget build(BuildContext context) {
    if (!mounted) return const Scaffold(body: Center(child: Text("Chargement...")));
    final authService = Provider.of<AuthService>(context);

    if (authService.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayCount = _isLoadingCounts ? '...' : _todayTotal.toString();
    final relaunchCount = _isLoadingCounts ? '...' : (_counts['reported'] ?? 0).toString();
    final returnsCount = _isLoadingCounts ? '...' : ((_counts['return_declared'] ?? 0) + (_counts['returned'] ?? 0)).toString();
    final unreadMessageCount = (_counts['unread_messages'] ?? 0);


    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les compteurs',
            onPressed: _fetchCounts,
          ),
          // *** MODIFICATION ICI ***
          IconButton(
            icon: Badge(
              isLabelVisible: unreadMessageCount > 0,
              label: Text(unreadMessageCount.toString()),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            tooltip: 'Discussions',
            onPressed: () {
              // Navigue vers le nouvel écran de liste de chats
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const GlobalChatListScreen(),
              ));
            },
          ),
          // ***********************
          const SizedBox(width: 8),
        ],
      ),

      drawer: Drawer( // --- Contenu du Drawer (inchangé) ---
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(authService.currentUser!.name),
              accountEmail: Text(authService.currentUser!.phoneNumber),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('À relancer'),
              trailing: _isLoadingCounts
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(relaunchCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OrdersRelaunchScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: const Text('Retours'),
               trailing: _isLoadingCounts
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(returnsCount, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OrdersReturnsScreen()));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Déconnexion', style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                await authService.logout();
              },
            ),
          ],
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      bottomNavigationBar: BottomNavigationBar( // --- (inchangé) ---
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(todayCount),
              isLabelVisible: _todayTotal > 0 && !_isLoadingCounts,
              backgroundColor: AppTheme.danger,
              child: const Icon(Icons.today),
            ),
            label: 'Aujourd\'hui',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Ma Caisse',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Performances',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}