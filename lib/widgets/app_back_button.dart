import 'package:flutter/material.dart';

/// Camada: Widgets (Botão de Voltar Reutilizável para AppBar)
/// Responsabilidade Única: Garantir que todas as telas secundárias exibam
/// um botão de voltar funcional mesmo quando a pilha de navegação é reiniciada
/// (ex.: atualização de página no Flutter Web), retornando para '/home' como fallback.
class AppBackButton extends StatelessWidget {
  final String fallbackRoute;

  const AppBackButton({
    super.key,
    this.fallbackRoute = '/home',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, fallbackRoute);
        }
      },
    );
  }
}
