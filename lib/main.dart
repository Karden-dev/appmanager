import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:wink_manager/screens/login_screen.dart';
import 'package:wink_manager/screens/main_navigation_screen.dart';
import 'package:wink_manager/providers/order_provider.dart';
import 'package:wink_manager/services/auth_service.dart';
import 'package:wink_manager/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser la localisation pour les dates (ex: "dd MMM yyyy")
  await initializeDateFormatting('fr_FR', null); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Fournir AuthService à la racine
        ChangeNotifierProvider(create: (_) => AuthService()),
        
        // 2. CORRECTION: Le ProxyProvider écoute AuthService
        // Signature correcte: create: (BuildContext context) => V
        // Signature correcte: update: (BuildContext context, T dependency, V? previousValue) => V
        ChangeNotifierProxyProvider<AuthService, OrderProvider>(
          // Ligne 30: 1 argument attendu
          create: (context) => OrderProvider(AuthService()), 
          
          // Ligne 35: 3 arguments attendus
          update: (context, auth, previousProvider) { 
            // Si 'auth' est authentifié, OrderProvider utilisera le bon 'dio'
            return OrderProvider(auth); 
          },
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
            
            // Gestion des routes au cas où
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