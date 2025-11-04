// winkmanager/utils/app_theme.dart

import 'package:flutter/material.dart'; // <-- L'importation CLÉ pour ColorScheme

class AppTheme {
  // Couleurs principales basées sur le CSS fourni
  static const Color primaryColor = Color(0xFFFF7F50); // --clr-primary: Corail
  static const Color primaryLight = Color(0xFFFFD8C7); // Corail clair pour les fonds de cartes
  static const Color secondaryColor = Color(0xFF2C3E50); // --clr-secondary: Bleu Profond
  static const Color accentColor = Color(0xFF4A6491); // --clr-accent: Bleu Céleste
  static const Color background = Color(0xFFF8F9FA); // --clr-background: Blanc Crème
  static const Color text = Color(0xFF34495E); // --clr-text: Gris Anthracite
  static const Color danger = Color(0xFFdc3545); // Pour les statuts annulés/ratés
  static const Color success = Color(0xFF28a745); // Pour les statuts livrés
  static const Color info = Color(0xFF0dcaf0); // Pour les statuts "Prêt" ou Infos

  static final ThemeData lightTheme = ThemeData(
    // 1. Activation de Material 3
    useMaterial3: true,
    
    // 2. Définition du schéma de couleurs M3 explicite
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor, // Le Corail comme couleur de base pour générer les nuances
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      surface: background, // Blanc Crème
      onSurface: text, // Gris Anthracite
      error: danger,
      onError: Colors.white,
      // Ajout de couleurs M3 pour les conteneurs
      primaryContainer: primaryLight,
      // Correction Dépréciation: Remplacement de withOpacity par withAlpha
      secondaryContainer: accentColor.withAlpha((255 * 0.2).round()), 
      onPrimaryContainer: secondaryColor,
      onSecondaryContainer: secondaryColor,
    ),
    
    scaffoldBackgroundColor: background,

    // Thème de l'AppBar (M3 modernisé)
    // Ajout de const pour l'optimisation
    appBarTheme: const AppBarTheme( 
      backgroundColor: secondaryColor, 
      foregroundColor: Colors.white,
      elevation: 0, 
      scrolledUnderElevation: 4, 
      centerTitle: true,
      titleTextStyle: TextStyle( 
        fontSize: 20, 
        fontWeight: FontWeight.bold, 
        color: Colors.white
      ),
    ),

    // Thème des boutons principaux (ElevatedButton)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryColor, 
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), 
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        elevation: 1,
      ),
    ),
    
    // Thème des Floating Action Buttons (M3)
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: CircleBorder(), 
    ),

    // Thème des champs de saisie (Inputs) - Style M3 Outlined
    inputDecorationTheme: InputDecorationTheme(
      // Utilisation des propriétés M3:
      labelStyle: const TextStyle(color: text),
      floatingLabelStyle: const TextStyle(color: primaryColor),
      hintStyle: TextStyle(color: Colors.grey.shade500),

      // Ajout de const pour l'optimisation
      focusedBorder: const OutlineInputBorder( 
        borderSide: BorderSide(color: primaryColor, width: 2.0),
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      enabledBorder: OutlineInputBorder( 
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
        borderRadius: BorderRadius.circular(12.0),
      ),
      // Ajout de const pour l'optimisation
      errorBorder: const OutlineInputBorder( 
        borderSide: BorderSide(color: danger),
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      // Ajout de const pour l'optimisation
      focusedErrorBorder: const OutlineInputBorder( 
        borderSide: BorderSide(color: danger, width: 2.0),
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
    ),

    // Thème des cartes 
    // CORRECTION CRITIQUE: RETRAIT DU 'const' car BorderRadius.circular(12.0) n'est pas const.
    cardTheme: CardThemeData( 
      elevation: 1, 
      color: Colors.white,
      surfaceTintColor: Colors.white, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), 
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0), 
    ),

    // Thème des textes
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor), 
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: text), 
      bodyLarge: TextStyle(color: text, fontSize: 16), 
      labelLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), 
    ),
  );
}