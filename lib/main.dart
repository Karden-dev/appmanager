// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:wink_manager/repositories/order_repository.dart';
import 'package:wink_manager/screens/login_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/services/admin_order_service.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/services/database_service.dart';
import 'package:wink_manager/utils/app_theme.dart';
import 'package:wink_manager/services/sync_service.dart';
import 'package:wink_manager/providers/network_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null); 
  
  await DatabaseService.instance.database;
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. AuthService (Indépendant)
        ChangeNotifierProvider(create: (_) => AuthService()),
        
        // 2. NetworkProvider (Indépendant)
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        
        // 3. AdminOrderService (Dépend de AuthService)
        ProxyProvider<AuthService, AdminOrderService>(
          update: (_, auth, __) => AdminOrderService(auth),
        ),
        
        // 4. OrderRepository (Dépend de AdminOrderService)
        ProxyProvider<AdminOrderService, OrderRepository>(
          update: (_, apiService, __) => OrderRepository(
            apiService, 
            DatabaseService.instance 
          ),
        ),

        // 5. CORRECTION : SyncService (DÉPLACÉ AVANT OrderProvider)
        // (Dépend de AdminOrderService ET OrderRepository)
        ProxyProvider2<AdminOrderService, OrderRepository, SyncService>(
          // Note: Pas de 'create', 'update' suffit pour les ProxyProviders
          update: (_, apiService, repository, __) => SyncService(
            apiService,
            DatabaseService.instance,
            repository, 
          ),
          // 'lazy: false' pourrait être utile ici si l'init ne se fait pas, 
          // mais laissons par défaut pour l'instant.
        ),

        // 6. CORRECTION : OrderProvider (DÉPEND MAINTENANT DE SyncService)
        // (Dépend de OrderRepository ET SyncService)
        ChangeNotifierProxyProvider2<OrderRepository, SyncService, OrderProvider>(
          create: (context) => OrderProvider(
            Provider.of<OrderRepository>(context, listen: false),
            Provider.of<SyncService>(context, listen: false) // Injection du SyncService
          ),
          update: (context, repository, syncService, previousProvider) => OrderProvider(
            repository, 
            syncService // Passe le SyncService à chaque mise à jour
          ),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'Wink Manager',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            
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