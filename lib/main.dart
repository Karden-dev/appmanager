// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Repositories
import 'package:wink_manager/repositories/order_repository.dart';
import 'package:wink_manager/repositories/chat_repository.dart';
// *** NOUVEL IMPORT (qui fonctionne maintenant) ***
import 'package:wink_manager/repositories/report_repository.dart';

// Screens
import 'package:wink_manager/screens/login_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';

// Providers
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/providers/network_provider.dart';
import 'package:wink_manager/providers/chat_provider.dart';
import 'package:wink_manager/providers/report_provider.dart'; 

// Services
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/sync_service.dart';
import 'package:wink_manager/services/websocket_service.dart';
import 'package:wink_manager/services/chat_service.dart';
import 'package:wink_manager/services/report_service.dart'; 

import 'package:wink_manager/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialise la BDD (gère la migration v4)
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

        // --- REPOSITORIES (DB LOCAL + API) ---
        ProxyProvider2<AdminOrderService, DatabaseService, OrderRepository>(
          update: (_, apiService, dbService, __) =>
              OrderRepository(apiService, dbService),
        ),
        ProxyProvider<DatabaseService, ChatRepository>(
          update: (_, dbService, __) => ChatRepository(dbService),
        ),
        // *** NOUVEAU : ReportRepository ***
        ProxyProvider3<ReportService, DatabaseService, OrderRepository, ReportRepository>(
          update: (_, apiService, dbService, orderRepo, __) =>
              ReportRepository(apiService, dbService, orderRepo),
        ),

        // --- SERVICES DE SYNCHRONISATION (Réseau + DB) ---
        ProxyProvider3<AdminOrderService, DatabaseService, OrderRepository, SyncService>(
          update: (_, apiService, dbService, orderRepo, __) =>
              SyncService(apiService, dbService, orderRepo),
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
        ChangeNotifierProxyProvider2<OrderRepository, SyncService, OrderProvider>(
          create: (context) => OrderProvider(
            Provider.of<OrderRepository>(context, listen: false),
            Provider.of<SyncService>(context, listen: false),
          ),
          update: (_, repository, syncService, previousProvider) =>
              OrderProvider(repository, syncService),
        ),

        // *** MODIFICATION : ReportProvider dépend de ReportRepository ***
        ChangeNotifierProxyProvider2<ReportRepository, NetworkProvider, ReportProvider>(
          create: (context) => ReportProvider(
            Provider.of<ReportRepository>(context, listen: false),
            Provider.of<NetworkProvider>(context, listen: false),
          ),
          update: (_, reportRepo, networkProvider, previousProvider) =>
              ReportProvider(reportRepo, networkProvider),
        ),
        // *** FIN MODIFICATION ***

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
            previousChatProvider?.dispose();
            return null;
          },
          lazy: false,
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
            home: authService.isAuthenticated
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