import 'package:flutter/material.dart';

/// Camada: Theme (Identidade Visual e Design System)
/// Responsabilidade Única: Centralizar todas as cores, fontes e estilos de botões/inputs
/// da aplicação para garantir consistência visual e alto contraste (foco em Acessibilidade).
class AppTheme {
  // Construtor privado para impedir instanciação (classe utilitária estática)
  AppTheme._();

  // Paleta CitizenTech — Alto contraste para acessibilidade visual
  static const Color primaryBlue = Color(0xFF0D47A1); // Azul institucional profundo
  static const Color secondaryTeal = Color(0xFF00796B); // Verde-azulado para mobilidade/acessibilidade
  static const Color accentAmber = Color(0xFFF57C00); // Laranja/Âmbar para alertas de atenção
  static const Color dangerRed = Color(0xFFD32F2F); // Vermelho para ocorrências críticas/elevador inoperante
  static const Color successGreen = Color(0xFF2E7D32); // Verde para ônibus acessível / resolvido
  static const Color surfaceBackground = Color(0xFFF4F6F9); // Fundo claro suave para destacar os cards

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: secondaryTeal,
      error: dangerRed,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
