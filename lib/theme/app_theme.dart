import 'package:flutter/material.dart';

/// Camada: Theme (Identidade Visual e Design System)
/// Responsabilidade Única: Centralizar todas as cores, fontes e estilos de botões/inputs
/// da aplicação (Claro e Escuro) para garantir consistência visual, alvos de toque
/// acessíveis (48x48dp) e alto contraste.
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

  // Paleta Modo Escuro (Alto contraste noturno)
  static const Color darkBackground = Color(0xFF101820);
  static const Color darkSurface = Color(0xFF18232F);
  static const Color darkCard = Color(0xFF202D3A);
  static const Color darkBorder = Color(0xFF3B4A5A);
  static const Color darkText = Color(0xFFF5F7FA);
  static const Color darkSecondaryText = Color(0xFFC4CDD6);
  static const Color darkBlue = Color(0xFF8AB4F8);
  static const Color darkTeal = Color(0xFF5AD1C4);

  static ThemeData get lightTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  // Helpers semânticos adaptativos para superfícies de destaque e status
  // (garantem alto contraste tanto no Brightness.light quanto no Brightness.dark)
  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color adaptiveSuccess(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

  static Color adaptiveWarning(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  static Color adaptiveDanger(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color badgeBgInfo(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF0C4A6E) : const Color(0xFFEFF6FF);

  static Color badgeBgSuccess(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);

  static Color badgeBgWarning(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);

  static Color badgeBgDanger(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);

  static Color softSurface(BuildContext context) =>
      isDarkMode(context) ? darkCard : const Color(0xFFF8FAFC);

  static ThemeData _buildTheme({required bool isDark}) {
    final background = isDark ? darkBackground : surfaceBackground;
    final surface = isDark ? darkSurface : Colors.white;
    final card = isDark ? darkCard : Colors.white;
    final text = isDark ? darkText : const Color(0xFF172B4D);
    final secondaryText = isDark ? darkSecondaryText : const Color(0xFF52606D);
    final primary = isDark ? darkBlue : primaryBlue;
    final secondary = isDark ? darkTeal : secondaryTeal;
    final border = isDark ? darkBorder : const Color(0xFFCFD8DC);

    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? darkBlue : primaryBlue,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF10223E) : Colors.white,
      secondary: secondary,
      error: isDark ? const Color(0xFFFF8A80) : dangerRed,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: border,
      textTheme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light)
          .textTheme
          .apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : primaryBlue,
        foregroundColor: isDark ? darkText : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? darkText : Colors.white,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? darkBorder : const Color(0xFFE5EAF0),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : Colors.white,
        hintStyle: TextStyle(color: secondaryText),
        labelStyle: TextStyle(color: secondaryText),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkCard : const Color(0xFF263238),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        textStyle: TextStyle(color: text, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconTheme: IconThemeData(color: secondaryText),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: text,
        minLeadingWidth: 28,
      ),
    );
  }
}
