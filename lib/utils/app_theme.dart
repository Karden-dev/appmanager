// Fichier : lib/utils/app_theme.dart

import 'package:flutter/material.dart';

/*
 * ===========================================================================
 * WINK MANAGER - PALETTE DE COULEURS (BASÉE SUR RIDERAPP)
 * ===========================================================================
 * [Primary] Bleu Wink: La couleur principale de l'branding.
 * [Secondary] Gris Foncé: Utilisé pour le texte principal et les en-têtes.
 * [Accent] Corail/Orange Vif: Pour les boutons d'action (CTA), les FABs, 
 * et les éléments interactifs.
 * [Text/Light] Gris Clair: Pour les sous-titres, placeholders.
 * [Background] Blanc Cassé/Gris très clair: Couleur de fond générale.
 * [Feedback]
 * [Success] Vert: Opérations réussies.
 * [Warning] Orange: Avertissements, statuts 'en attente'.
 * [Danger] Rouge: Erreurs, suppressions, statuts 'annulés'.
 * [Info] Bleu Clair: Pour les statuts 'en cours', 'prêt'.
 * ===========================================================================
 */

class AppTheme {
  
  // --- Palette de Couleurs (Synchronisée avec RiderApp) ---
  
  static const Color primaryColor = Color(0xFF0D47A1);    // Bleu Wink (foncé)
  static const Color primaryLight = Color(0xFFE3F2FD);   // Bleu Wink (très clair)
  static const Color secondaryColor = Color(0xFF333333); // Gris Foncé (Texte principal)
  static const Color accentColor = Color(0xFFFF6F61);     // Corail/Orange Vif (CTA)
  
  static const Color text = Color(0xFF333333);          // Texte normal
  static const Color textLight = Color(0xFF6c757d);      // Texte grisé
  static const Color background = Color(0xFFF8F9FA);    // Fond de l'application
  static const Color cardColor = Color(0xFFFFFFFF);      // Fond des cartes
  
  // Couleurs de Feedback
  static const Color success = Color(0xFF28a745);
  static const Color warning = Color(0xFFfd7e14);
  static const Color danger = Color(0xFFdc3545);
  static const Color info = Color(0xFF17a2b8);

  // Rayon de bordure standard
  static const double cardRadius = 12.0;

  /// Thème global de l'application (Mode Clair)
  static ThemeData get lightTheme {
    return ThemeData(
      // --- Configuration Générale ---
      brightness: Brightness.light,
      scaffoldBackgroundColor: background, 
      primaryColor: primaryColor,
      
      // --- Schéma de Couleurs (Material 3) ---
      colorScheme: const ColorScheme.light( 
        primary: primaryColor,                 
        onPrimary: Colors.white,               
        secondary: accentColor,                
        onSecondary: Colors.white,              
        surface: cardColor,                     
        onSurface: text,                        
        error: danger,                          
        onError: Colors.white,                  
        brightness: Brightness.light,
      ),

      // --- Thème de la Barre d'Application (AppBar) ---
      appBarTheme: const AppBarTheme(
        elevation: 1,
        scrolledUnderElevation: 2,
        backgroundColor: cardColor,             
        foregroundColor: secondaryColor,        
        iconTheme: IconThemeData(color: secondaryColor, size: 24),
        titleTextStyle: TextStyle(
          color: secondaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: null,
        ),
      ),

      // --- Thème des Boutons ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48), 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius / 2),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // --- Thème du Bouton d'Action Flottant (FAB) ---
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor, 
        foregroundColor: Colors.white,
      ),
      
      // --- Thème de la Barre de Navigation (Bottom Nav) ---
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        height: 65,
        elevation: 4,
        indicatorColor: primaryLight, 
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final color = states.contains(WidgetState.selected)
              ? primaryColor
              : textLight;
          return TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: color);
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final color = states.contains(WidgetState.selected)
              ? primaryColor
              : textLight;
          return IconThemeData(color: color, size: 24);
        }),
      ),

      // --- Thème des Cartes (Card) ---
      // FIX L121: Utilisation de CardThemeData explicite
      cardTheme: CardThemeData( 
        elevation: 2,
        color: cardColor, 
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius), 
        ),
      ),
      
      // --- Thème des Champs de Saisie (TextFormField) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background, 
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius / 2),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius / 2),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6.0)),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        // FIX L150: Remplacement du paramètre 'side' par 'borderSide'
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius / 2),
          borderSide: const BorderSide(color: danger, width: 1.5), 
        ),
        
        labelStyle: const TextStyle(color: textLight),
        hintStyle: const TextStyle(color: textLight),
        floatingLabelStyle: const TextStyle(color: primaryColor),
        isDense: true,
      ),

      // --- Thème des Polices ---
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: secondaryColor),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: secondaryColor),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
        bodyLarge: TextStyle(fontSize: 15, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: textLight),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textLight),
      ),
      
      // --- Thème des Dialogues ---
      // FIX L173: Utilisation de DialogThemeData explicite
      dialogTheme: DialogThemeData( 
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      
      // --- Thème des Chips/Badges ---
      chipTheme: ChipThemeData(
        backgroundColor: primaryLight,
        labelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius / 2),
        ),
        side: BorderSide.none,
      ),
    );
  }
}