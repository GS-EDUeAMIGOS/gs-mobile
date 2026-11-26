import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/models/favorito_model.dart';
import 'package:viacidada_mobile/screens/favorites_screen.dart';
import 'package:viacidada_mobile/services/api_service.dart';
import 'package:viacidada_mobile/theme/app_theme.dart';

void main() {
  setUp(() {
    ApiService.instance.logout();
  });

  test('Converte JSON de ParadaFavoritaDTO.Response corretamente', () {
    final parada = ParadaFavoritaModel.fromJson({
      'id': 10,
      'usuarioId': 2,
      'codigoParada': 340015329,
      'nomeParada': 'PARADA PAULISTA B/C',
      'endereco': 'Av. Paulista, 1578',
      'latitude': -23.5614,
      'longitude': -46.6559,
      'possuiRampaAcessivel': true,
      'possuiPisoTatil': false,
      'criadoEm': '2026-11-20T10:00:00',
    });

    expect(parada.id, 10);
    expect(parada.usuarioId, 2);
    expect(parada.codigoParada, 340015329);
    expect(parada.nomeParada, 'PARADA PAULISTA B/C');
    expect(parada.possuiRampaAcessivel, true);
    expect(parada.possuiPisoTatil, false);
    expect(parada.isAcessivel, true);
  });

  test('Converte JSON de LinhaFavoritaDTO.Response e monta descricaoTrajeto', () {
    final linha = LinhaFavoritaModel.fromJson({
      'id': 5,
      'usuarioId': 2,
      'codigoLinha': 2506,
      'letreiro': '8000-10',
      'sentido': 1,
      'terminalOrigem': 'TERM. LAPA',
      'terminalDestino': 'PÇA. RAMOS DE AZEVEDO',
      'apelido': 'Ônibus do Trabalho',
    });

    expect(linha.id, 5);
    expect(linha.codigoLinha, 2506);
    expect(linha.letreiro, '8000-10');
    expect(linha.apelido, 'Ônibus do Trabalho');
    expect(linha.descricaoTrajeto, 'TERM. LAPA ➔ PÇA. RAMOS DE AZEVEDO');
  });

  testWidgets('FavoritesScreen orienta login quando usuário está em modo visitante', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const FavoritesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meus Favoritos'), findsOneWidget);
    expect(find.text('Faça login para ver seus favoritos'), findsOneWidget);
    expect(find.text('Ir para Login'), findsOneWidget);
  });
}
