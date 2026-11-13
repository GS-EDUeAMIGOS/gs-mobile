import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/occurrence_detail_screen.dart';
import 'screens/occurrence_form_screen.dart';
import 'screens/occurrences_screen.dart';
import 'screens/route_planner_screen.dart';
import 'screens/sptrans_screen.dart';
import 'theme/app_theme.dart';

/// Ponto de entrada da aplicação Flutter (`main.dart`)
/// Responsabilidade Única: Inicializar o `MaterialApp`, aplicar o `AppTheme` (Design System)
/// e registrar a tabela de Rotas Nomeadas (`routes`) conectando as 7 telas do projeto.
void main() {
  runApp(const ViaCidadaApp());
}

class ViaCidadaApp extends StatelessWidget {
  const ViaCidadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViaCidadã • Mobilidade e Acessibilidade',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/occurrences': (context) => const OccurrencesScreen(),
        '/occurrence-detail': (context) => const OccurrenceDetailScreen(),
        '/occurrence-form': (context) => const OccurrenceFormScreen(),
        '/sptrans': (context) => const SptransScreen(),
        '/route-planner': (context) => const RoutePlannerScreen(),
      },
    );
  }
}
