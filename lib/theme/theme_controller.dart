import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camada: Theme (Gerenciamento de Aparência / Acessibilidade Visual)
/// Responsabilidade Única: Guardar a preferência visual local (Claro/Escuro)
/// e notificar a interface quando ela muda. Não contém regras de negócio.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.light}) : _mode = initialMode;

  ThemeController._(this._mode);

  static const String _preferenceKey = 'via_cidada_theme_mode';
  ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  static Future<ThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_preferenceKey);
    return ThemeController._(
      savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

/// Disponibiliza o `ThemeController` às telas sem adicionar dependências externas.
class ThemeControllerScope extends InheritedWidget {
  const ThemeControllerScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ThemeController controller;

  static ThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
        ?.controller;
  }

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'ThemeControllerScope não encontrado na árvore.');
    return controller!;
  }

  @override
  bool updateShouldNotify(ThemeControllerScope oldWidget) =>
      controller != oldWidget.controller;
}
