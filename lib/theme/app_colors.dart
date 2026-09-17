import 'package:flutter/material.dart';

/// Palette de couleurs centralisée de Stud'Home.
///
/// Toutes les Views doivent importer ce fichier plutôt que de redéfinir
/// leurs propres constantes de couleur — ça garantit une seule source
/// de vérité si la charte graphique évolue (ex: changement de teinte
/// principale), et évite les incohérences entre écrans.
class AppColors {
  AppColors._(); // classe non instanciable, uniquement des constantes statiques

  // Couleurs de marque
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFFEEF2FF);
  static const Color indigoMid = Color(0xFF818CF8);
  static const Color violet = Color(0xFF7C3AED);

  // Nuances de gris (échelle Tailwind, reprise des maquettes React)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);

  // Couleurs sémantiques (statuts, badges)
  static const Color green = Color(0xFF10B981);
  static const Color orange = Color(0xFFF59E0B);
}
