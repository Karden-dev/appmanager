// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// Repositories
import 'package:wink_manager/repositories/order_repository.dart';
import 'package:wink_manager/repositories/chat_repository.dart';
import 'package:wink_manager/repositories/report_repository.dart';
import 'package:wink_manager/repositories/remittance_repository.dart';
import 'package:wink_manager/repositories/debt_repository.dart';
import 'package:wink_manager/repositories/cash_repository.dart';
import 'package:wink_manager/repositories/shop_repository.dart';

// Screens
import 'package:wink_manager/screens/login_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';

// Providers
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/providers/network_provider.dart';
import 'package:wink_manager/providers/chat_provider.dart';
import 'package:wink_manager/providers/report_provider.dart';
import 'package:wink_manager/providers/remittance_provider.dart';
import 'package:wink_manager/providers/debt_provider.dart';
import 'package:wink_manager/providers/cash_provider.dart';
import 'package:wink_manager/providers/shop_provider.dart';
import 'package:wink_manager/providers/dashboard_provider.dart';

// Services
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/sync_service.dart';
import 'package:wink_manager/services/websocket_service.dart';
import 'package:wink_manager/services/chat_service.dart';
import 'package:wink_manager/services/report_service.dart';
import 'package:wink_manager/services/remittance_service.dart';
import 'package:wink_manager/services/debt_service.dart';
import 'package:wink_manager/services/cash_service.dart';
import 'package:wink_manager/services/shop_service.dart';
import 'package:wink_manager/services/dashboard_service.dart';
import 'package:wink_manager/services/stock_service.dart'; // <-- AJOUT : Service Stock

import 'package:wink_manager/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise les données de formatage pour la locale française
  await initializeDateFormatting('fr_FR', null);

  // Définit la locale par défaut pour tout le package intl
  Intl.defaultLocale = 'fr_FR';

  // Initialise la BDD
  await DatabaseService.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- SERVICES INDÉPENDANTS ---
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        Provider<DatabaseService>.value(value: DatabaseService.instance),

        // --- SERVICES DÉPENDANTS (API) ---
        ProxyProvider<AuthService, AdminOrderService>(
          update: (_, auth, __) => AdminOrderService(auth),
        ),
        ProxyProvider<AuthService, ChatService>(
          update: (_, auth, __) => ChatService(auth),
        ),
        ProxyProvider<AuthService, ReportService>(
          update: (_, auth, __) => ReportService(auth),
        ),
        ProxyProvider<AuthService, RemittanceService>(
          update: (_, auth, __) => RemittanceService(auth),
        ),
        ProxyProvider<AuthService, DebtService>(
          update: (_, auth, __) => DebtService(auth),
        ),
        ProxyProvider<AuthService, CashService>(
          update: (_, auth, __) => CashService(auth),
        ),
        ProxyProvider<AuthService, ShopService>(
          update: (_, auth, __) => ShopService(auth),
        ),
        ProxyProvider<AuthService, DashboardService>(
          update: (_, auth, __) => DashboardService(auth),
        ),
        // --- NOUVEAU : Service Stock ---
        ProxyProvider<AuthService, StockService>(
          update: (_, auth, __) => StockService(auth),
        ),

        // --- REPOSITORIES (DB LOCAL + API) ---
        ProxyProvider2<AdminOrderService, DatabaseService, OrderRepository>(
          update: (_, apiService, dbService, __) =>
              OrderRepository(apiService, dbService),
        ),
        ProxyProvider<DatabaseService, ChatRepository>(
          update: (_, dbService, __) => ChatRepository(dbService),
        ),
        ProxyProvider3<ReportService, DatabaseService, OrderRepository, ReportRepository>(
          update: (_, apiService, dbService, orderRepo, __) =>
              ReportRepository(apiService, dbService, orderRepo),
        ),
        ProxyProvider2<RemittanceService, DatabaseService, RemittanceRepository>(
          update: (_, apiService, dbService, __) =>
              RemittanceRepository(apiService, dbService),
        ),
        ProxyProvider2<DebtService, DatabaseService, DebtRepository>(
          update: (_, apiService, dbService, __) =>
              DebtRepository(apiService, dbService),
        ),
        ProxyProvider2<CashService, DatabaseService, CashRepository>(
          update: (_, apiService, dbService, __) =>
              CashRepository(apiService, dbService),
        ),
        ProxyProvider2<ShopService, DatabaseService, ShopRepository>(
          update: (_, apiService, dbService, __) =>
              ShopRepository(apiService, dbService),
        ),

        // --- SERVICES DE SYNCHRONISATION (Réseau + DB) ---
        ProxyProvider2<AdminOrderService, DatabaseService, SyncService>(
          update: (_, apiService, dbService, __) =>
              SyncService(apiService, dbService),
          lazy: false,
        ),

        ChangeNotifierProxyProvider<AuthService, WebSocketService>(
          create: (context) => WebSocketService(
            Provider.of<AuthService>(context, listen: false),
          ),
          update: (context, auth, previousWs) =>
              previousWs!..onAuthStateChanged(),
          lazy: false,
        ),

        // --- PROVIDERS (UI STATE) ---

        ChangeNotifierProxyProvider<OrderRepository, OrderProvider>(
          create: (context) => OrderProvider(
            Provider.of<OrderRepository>(context, listen: false),
          ),
          update: (_, repository, previousProvider) {
            if (previousProvider != null) {
              previousProvider.update(repository);
              return previousProvider;
            }
            return OrderProvider(repository);
          },
        ),

        ChangeNotifierProxyProvider2<ReportRepository, NetworkProvider, ReportProvider>(
          create: (context) => ReportProvider(
            Provider.of<ReportRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, reportRepo, networkProvider, previousProvider) =>
              ReportProvider(reportRepo, networkProvider),
        ),

        ChangeNotifierProxyProvider2<RemittanceRepository, NetworkProvider, RemittanceProvider>(
          create: (context) => RemittanceProvider(
            Provider.of<RemittanceRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, repo, net, prev) {
            if (prev != null) {
              prev.update(repo);
              return prev;
            }
            return RemittanceProvider(repo, net);
          },
        ),

        ChangeNotifierProxyProvider2<DebtRepository, NetworkProvider, DebtProvider>(
          create: (context) => DebtProvider(
            Provider.of<DebtRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, repo, net, prev) {
            if (prev != null) {
              prev.update(repo);
              return prev;
            }
            return DebtProvider(repo, net);
          },
        ),

        ChangeNotifierProxyProvider2<CashRepository, NetworkProvider, CashProvider>(
          create: (context) => CashProvider(
            Provider.of<CashRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, repo, net, prev) {
            if (prev != null) {
              prev.update(repo);
              return prev;
            }
            return CashProvider(repo, net);
          },
        ),

        ChangeNotifierProxyProvider2<ShopRepository, NetworkProvider, ShopProvider>(
          create: (context) => ShopProvider(
            Provider.of<ShopRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, repo, net, prev) {
            if (prev != null) {
              prev.update(repo);
              return prev;
            }
            return ShopProvider(repo, net);
          },
        ),

        ChangeNotifierProxyProvider<DashboardService, DashboardProvider>(
          create: (context) => DashboardProvider(
            Provider.of<DashboardService>(context, listen: false),
          ),
          update: (_, service, prev) => prev ?? DashboardProvider(service),
        ),

        ChangeNotifierProxyProvider4<AuthService, ChatService, WebSocketService,
            ChatRepository, ChatProvider?>(
          create: (context) {
            final auth = Provider.of<AuthService>(context, listen: false);
            if (auth.isAuthenticated) {
              return ChatProvider(
                auth,
                Provider.of<ChatService>(context, listen: false),
                Provider.of<WebSocketService>(context, listen: false),
                Provider.of<ChatRepository>(context, listen: false),
              );
            }
            return null;
          },
          update: (context, auth, chatService, wsService, chatRepo, previousChatProvider) {
            if (auth.isAuthenticated) {
              if (previousChatProvider == null) {
                return ChatProvider(auth, chatService, wsService, chatRepo);
              }
              return previousChatProvider;
            }
            return null;
          },
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'Wink Manager',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
            ],
            locale: const Locale('fr', 'FR'),

            home: authService.isLoading
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : authService.isAuthenticated
                    ? const MainNavigationScreen()
                    : const LoginScreen(),

            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainNavigationScreen(),
            },
          );
        },
      ),
    );
  }
}