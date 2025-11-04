// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <-- AJOUTÉ

// Repositories
import 'package:wink_manager/repositories/order_repository.dart';
import 'package:wink_manager/repositories/chat_repository.dart'; // <-- AJOUTÉ

// Screens
import 'package:wink_manager/screens/login_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';

// Providers
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/providers/network_provider.dart';
import 'package:wink_manager/providers/chat_provider.dart'; // <-- AJOUTÉ

// Services
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/services/sync_service.dart';
// import 'package:wink_manager/services/notification_service.dart'; // <-- SUPPRIMÉ
import 'package:wink_manager/services/websocket_service.dart'; // <-- AJOUTÉ
import 'package:wink_manager/services/chat_service.dart'; // <-- AJOUTÉ

import 'package:wink_manager/utils/app_theme.dart';

// --- Instance de NotificationService supprimée ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialise la base de données (qui gère maintenant les migrations)
  await DatabaseService.instance.database;

  // --- Initialisation des notifications supprimée ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- SERVICES INDÉPENDANTS ---
        // 1. AuthService (Indépendant)
        ChangeNotifierProvider(create: (_) => AuthService()),

        // 2. NetworkProvider (Indépendant)
        ChangeNotifierProvider(create: (_) => NetworkProvider()),

        // 3. DatabaseService (Singleton)
        Provider<DatabaseService>.value(value: DatabaseService.instance),
        
        // --- SUPPRIMÉ : NotificationService ---

        // --- SERVICES DÉPENDANTS (API) ---
        // 4. AdminOrderService (Dépend de AuthService)
        ProxyProvider<AuthService, AdminOrderService>(
          update: (_, auth, __) => AdminOrderService(auth),
        ),
        
        // 5. ChatService (Dépend de AuthService) - AJOUTÉ
        ProxyProvider<AuthService, ChatService>(
          update: (_, auth, __) => ChatService(auth),
        ),

        // --- REPOSITORIES (DB LOCAL) ---
        // 6. OrderRepository (Dépend de AdminOrderService et DatabaseService)
        ProxyProvider2<AdminOrderService, DatabaseService, OrderRepository>(
          update: (_, apiService, dbService, __) =>
              OrderRepository(apiService, dbService),
        ),
        
        // 7. ChatRepository (Dépend de DatabaseService) - AJOUTÉ
        ProxyProvider<DatabaseService, ChatRepository>(
          update: (_, dbService, __) => ChatRepository(dbService),
        ),

        // --- SERVICES DE SYNCHRONISATION (Réseau + DB) ---
        // 8. SyncService (Dépend de AdminOrderService, DB, OrderRepository)
        ProxyProvider3<AdminOrderService, DatabaseService, OrderRepository, SyncService>(
          update: (_, apiService, dbService, orderRepo, __) =>
              SyncService(apiService, dbService, orderRepo),
          lazy: false, // Initialiser tôt pour écouter la connectivité
        ),

        // 9. WebSocketService (Dépend de AuthService) - MODIFIÉ
        ChangeNotifierProxyProvider<AuthService, WebSocketService>(
          create: (context) => WebSocketService(
            Provider.of<AuthService>(context, listen: false),
          ),
          update: (context, auth, previousWs) =>
              previousWs!..onAuthStateChanged(), // Force la mise à jour si l'auth change
          lazy: false, // Démarrer le service immédiatement
        ),

        // --- PROVIDERS (UI STATE) ---
        // 10. OrderProvider (Dépend de OrderRepository, SyncService)
        ChangeNotifierProxyProvider2<OrderRepository, SyncService, OrderProvider>(
          create: (context) => OrderProvider(
            Provider.of<OrderRepository>(context, listen: false),
            Provider.of<SyncService>(context, listen: false),
          ),
          update: (_, repository, syncService, previousProvider) =>
              OrderProvider(repository, syncService),
        ),

        // 11. ChatProvider (Dépend de 4 services/repos) - AJOUTÉ
        ChangeNotifierProxyProvider4<AuthService, ChatService, WebSocketService,
            ChatRepository, ChatProvider?>(
          create: (context) {
            // Ne crée que si tout est prêt
            final auth = Provider.of<AuthService>(context, listen: false);
            if (auth.isAuthenticated) {
              return ChatProvider(
                auth,
                Provider.of<ChatService>(context, listen: false),
                Provider.of<WebSocketService>(context, listen: false),
                Provider.of<ChatRepository>(context, listen: false),
              );
            }
            return null; // Retourne null si non authentifié
          },
          update: (context, auth, chatService, wsService, chatRepo, previousChatProvider) {
            if (auth.isAuthenticated) {
              // Si on vient de se connecter, ou si le provider n'existait pas
              if (previousChatProvider == null) {
                return ChatProvider(auth, chatService, wsService, chatRepo);
              }
              // Si déjà existant, il se gère lui-même (il écoute AuthService)
              return previousChatProvider;
            }
            // Si on se déconnecte, on dispose l'ancien provider
            previousChatProvider?.dispose();
            return null;
          },
          lazy: false, // Démarrer dès que l'utilisateur est authentifié
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'Wink Manager',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,

            // --- AJOUTÉ : Localisation pour le DatePicker ---
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
            ],
            locale: const Locale('fr', 'FR'),
            // --- FIN AJOUT ---

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