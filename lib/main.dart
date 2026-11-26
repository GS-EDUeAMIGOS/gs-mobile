import 'package:flutter/material.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/occurrence_detail_screen.dart';
import 'screens/occurrence_form_screen.dart';
import 'screens/occurrences_screen.dart';
import 'screens/route_navigation_screen.dart';
import 'screens/route_planner_screen.dart';
import 'screens/sptrans_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Ponto de entrada da aplicação Flutter (`main.dart`)
/// Responsabilidade Única: Carregar a preferência de tema e ambiente da API, inicializar o `MaterialApp`
/// com `AppTheme` (claro/escuro) e registrar a tabela de Rotas Nomeadas (`routes`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.loadSavedEnvironment();
  final themeController = await ThemeController.load();
  runApp(ViaCidadaApp(themeController: themeController));
}

class ViaCidadaApp extends StatelessWidget {
  const ViaCidadaApp({this.themeController, super.key});

  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? ThemeController();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ThemeControllerScope(
        controller: controller,
        child: MaterialApp(
          title: 'ViaCidadã • Mobilidade e Acessibilidade',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: controller.mode,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/occurrences': (context) => const OccurrencesScreen(),
            '/occurrence-detail': (context) => const OccurrenceDetailScreen(),
            '/occurrence-form': (context) => const OccurrenceFormScreen(),
            '/sptrans': (context) => const SptransScreen(),
            '/route-planner': (context) => const RoutePlannerScreen(),
            '/route-navigation': (context) => const RouteNavigationScreen(),
          },
        ),
      ),
    );
  }
}
