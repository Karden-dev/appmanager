// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Correction des imports
import 'package:intl/date_symbol_data_local.dart';
// *** AJOUTÉ POUR LES TRADUCTIONS DES WIDGETS FLUTTER (DatePicker, etc.) ***
import 'package:flutter_localizations/flutter_localizations.dart'; 

import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/websocket_service.dart';
import 'services/notification_service.dart';
// Correction du chemin d'import pour SyncService
import 'services/sync_service.dart';        
import 'services/performance_service.dart'; // Import non utilisé a été retiré

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

// Déclaration globale du NotificationService
final NotificationService _notificationService = NotificationService();

void main() async {
  // Assure que les bindings sont prêts avant toute opération asynchrone (comme les appels intl)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Chargement de la locale pour le FORMATAGE (dd/MM/yyyy)
  await initializeDateFormatting('fr_FR', null); 
  
  await _notificationService.initialize();

  final authService = AuthService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (context) => authService),

        // SyncService
        ChangeNotifierProxyProvider<AuthService, SyncService?>(
          create: (_) => null, 
          update: (context, auth, previousSyncService) {
            final dio = auth.dio;
            final syncService = previousSyncService ?? SyncService(dio, _notificationService); 
            syncService.initializeConnectivityListener();
            return syncService;
          },
          lazy: false,
        ),

        // WebSocketService
        ChangeNotifierProxyProvider<AuthService, WebSocketService?>(
          create: (_) => null,
          update: (context, auth, previousWebSocketService) {
            final dio = auth.dio;
            if (auth.isAuthenticated && auth.currentUser != null) {
              final wsService = previousWebSocketService ?? WebSocketService(dio, _notificationService);
              if (!wsService.isConnected) {
                wsService.connect(auth.currentUser!);
              }
              return wsService;
            }
            previousWebSocketService?.disconnect();
            return null;
          },
          lazy: false,
        ),

        // OrderService (Dépend d'AuthService et SyncService)
        ProxyProvider2<AuthService, SyncService?, OrderService?>(
          update: (context, auth, sync, previousOrderService) {
            if (auth.isAuthenticated && auth.currentUser != null && sync != null) {
              return OrderService(auth.dio, auth.currentUser!, sync);
            }
            return null;
          },
          lazy: true,
        ),

        // PerformanceService (Dépend d'AuthService)
        ProxyProvider<AuthService, PerformanceService?>(
          update: (context, auth, previousPerformanceService) {
            if (auth.isAuthenticated) {
              return PerformanceService(auth.dio);
            }
            return null;
          },
          lazy: true,
        ),
      ],
      child: WinkRiderApp(authService: authService),
    ),
  );
}

class WinkRiderApp extends StatefulWidget {
  final AuthService authService;
  const WinkRiderApp({super.key, required this.authService});

  @override
  State<WinkRiderApp> createState() => _WinkRiderAppState();
}

class _WinkRiderAppState extends State<WinkRiderApp> {
  late Future<void> _initAuthFuture;

  @override
  void initState() {
    super.initState();
    _initAuthFuture = widget.authService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinkRider',
      theme: AppTheme.lightTheme,

      // *** AJOUTÉ POUR CORRIGER LE BUG DU DATEPICKER ***
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'), // Définit le Français (France) comme locale supportée
        // Locale('en', 'US'), // Optionnel: ajouter l'anglais si nécessaire
      ],
      locale: const Locale('fr', 'FR'), // Force la locale française pour l'application
      // ***********************************************

      home: FutureBuilder<void>(
        future: _initAuthFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
             return Scaffold(
              body: Center(
                child: Text('Erreur au démarrage: ${snapshot.error}'),
              ),
            );
          }

          return Consumer<AuthService>(
            builder: (context, auth, child) {
              return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
            },
          );
        },
      ),
    );
  }
}