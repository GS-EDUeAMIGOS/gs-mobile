import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// Camada: Widgets (Componentes Visuais Reutilizáveis)
/// Responsabilidade Única: Ação compacta de AppBar para alternar entre os
/// temas claro e escuro, com suporte a leitores de tela (`Semantics`).
class ThemeSelectorButton extends StatelessWidget {
  const ThemeSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeControllerScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDark;
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Escolher aparência',
          icon: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          ),
          onSelected: controller.setMode,
          itemBuilder: (context) => [
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: Semantics(
                label: 'Tema claro${isDark ? '' : ', selecionado'}',
                child: Row(
                  children: [
                    const Icon(Icons.light_mode_outlined),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Claro')),
                    if (!isDark)
                      const Icon(Icons.check, semanticLabel: 'Selecionado'),
                  ],
                ),
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: Semantics(
                label: 'Tema escuro${isDark ? ', selecionado' : ''}',
                child: Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Escuro')),
                    if (isDark)
                      const Icon(Icons.check, semanticLabel: 'Selecionado'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
