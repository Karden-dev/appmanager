// Fichier : lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; 
// --- AJOUTS NÉCESSAIRES ---\r\n
import 'package:flutter_localizations/flutter_localizations.dart';
// --- FIN DES AJOUTS ---\r\n
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
        
        // 2. Le ProxyProvider écoute AuthService et crée OrderProvider
        ChangeNotifierProxyProvider<AuthService, OrderProvider>(
          create: (BuildContext context) => OrderProvider(Provider.of<AuthService>(context, listen: false)), // La classe V (OrderProvider)
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

            // --- AJOUTS NÉCESSAIRES POUR CORRIGER LE CRASH ---\r\n
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'), // Définit le Français (France) comme locale supportée
              // Locale('en', 'US'), // Optionnel
            ],
            locale: const Locale('fr', 'FR'), // Force la locale française
            // --- FIN DES AJOUTS ---
            
            // L'objet authService est non-null ici.
            home: authService.isAuthenticated
                ? const MainNavigationScreen()
                // FIX L46 (Sévérité 8): Remplacer auth.init() par auth.tryAutoLogin()
                : FutureBuilder(
                    future: authService.tryAutoLogin(),
                    // FIX L49, L50 (Sévérité 2): Ajout de const
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return const LoginScreen();
                    },
                  ),
            
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