import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/main.dart';
import 'package:viacidada_mobile/models/olho_vivo_model.dart';
import 'package:viacidada_mobile/screens/route_navigation_screen.dart';
import 'package:viacidada_mobile/screens/route_planner_screen.dart';
import 'package:viacidada_mobile/screens/sptrans_screen.dart';
import 'package:viacidada_mobile/services/paradas_linha_fallback_helper.dart';
import 'package:viacidada_mobile/widgets/ponto_map_widget.dart';

void main() {
  testWidgets('Renderiza a tela inicial de Login do ViaCidada', (WidgetTester tester) async {
    await tester.pumpWidget(const ViaCidadaApp());

    expect(find.text('ViaCidadã'), findsOneWidget);
    expect(find.text('Entrar na Plataforma'), findsOneWidget);
  });

  test('Converte JSON do Planejador de Rotas Estilo Moovit (Direta e Baldeacao)', () {
    final json = {
      'origemBuscada': 'LAPA',
      'destinoBuscado': 'PAULISTA',
      'horarioConsulta': '18:20',
      'opcoes': [
        {
          'titulo': 'Linha Direta • 875A-10',
          'tipoRota': 'DIRETA',
          'recomendada': true,
          'motivoRecomendacao': 'Melhor opcao sem baldeacao',
          'totalOnibusNecessarios': 1,
          'tempoEstimadoMinutos': 28,
          'totalmenteAcessivelPcD': true,
          'totalOcorrenciasNoTrajeto': 0,
          'passos': [
            {
              'ordem': 1,
              'tipoPasso': 'EMBARQUE_DIRETO',
              'instrucao': 'Embarque na linha 875A-10',
              'local': 'PARADA LAPA',
              'codigoParada': 340015330,
              'nomeParada': 'CLINICAS B/C',
              'enderecoParada': 'AV PAULISTA',
              'latitudeParada': -23.5567,
              'longitudeParada': -46.6623,
              'pontoConfirmadoNaParada': true,
              'codigoLinha': 1234,
              'letreiroCompleto': '875A-10',
              'descricaoSentido': 'LAPA ➔ PAULISTA',
              'veiculosCirculando': 4,
              'veiculosAcessiveisPcD': 4,
              'proximoPrefixo': '12540',
              'latitudeProximoVeiculo': -23.5540,
              'longitudeProximoVeiculo': -46.6600,
              'previsaoChegada': 'Chegada prevista no ponto as 18:25',
              'ocorrenciasAbertas': 0,
            }
          ]
        }
      ]
    };

    final model = RotaPlanejadaResponseModel.fromJson(json);
    expect(model.origemBuscada, 'LAPA');
    expect(model.destinoBuscado, 'PAULISTA');
    expect(model.opcoes.length, 1);
    expect(model.opcoes.first.recomendada, true);
    expect(model.opcoes.first.passos.first.letreiroCompleto, '875A-10');
    expect(model.opcoes.first.passos.first.pontoConfirmadoNaParada, true);
    expect(model.opcoes.first.passos.first.possuiCoordenadasParada, true);
  });

  test('Identifica lado da via (B/C e C/B) e calcula distancia Haversine ate o ponto', () {
    const paradaBC = ParadaResumoModel(
      codigoParada: 1,
      nomeParada: 'TRIANON MASP B/C',
      endereco: 'AV PAULISTA',
      latitude: -23.5614,
      longitude: -46.6558,
    );
    const paradaCB = ParadaResumoModel(
      codigoParada: 2,
      nomeParada: 'TRIANON MASP C/B',
      endereco: 'AV PAULISTA',
      latitude: -23.5616,
      longitude: -46.6560,
    );

    expect(paradaBC.ladoDaViaExplicado, 'Sentido Bairro ➔ Centro (B/C)');
    expect(paradaCB.ladoDaViaExplicado, 'Sentido Centro ➔ Bairro (C/B)');

    final distancia = PontoMapWidget.calcularDistanciaMetros(
      paradaBC.latitude,
      paradaBC.longitude,
      paradaCB.latitude,
      paradaCB.longitude,
    );
    expect(distancia, greaterThan(10));
    expect(distancia, lessThan(100));
  });

  test('Mapeia veiculos em tempo real para a parada mais proxima da linha', () {
    const parada1 = ParadaResumoModel(
      codigoParada: 101,
      nomeParada: 'PARADA PAULISTA',
      endereco: 'AV PAULISTA, 1000',
      latitude: -23.5614,
      longitude: -46.6558,
    );
    const parada2 = ParadaResumoModel(
      codigoParada: 102,
      nomeParada: 'PARADA CONSOLACAO',
      endereco: 'R DA CONSOLACAO, 2000',
      latitude: -23.5550,
      longitude: -46.6620,
    );
    const veiculoPertoParada1 = VeiculoPosicaoModel(
      prefixo: '41234',
      acessivelPcD: true,
      horarioCaptura: '13:50:00',
      latitude: -23.5615,
      longitude: -46.6559,
    );

    final mapa = RouteNavigationScreen.mapearVeiculosNasParadas(
      [parada1, parada2],
      [veiculoPertoParada1],
    );

    expect(mapa.containsKey(101), true);
    expect(mapa.containsKey(102), false);
    expect(mapa[101]!.first.veiculo.prefixo, '41234');
    expect(mapa[101]!.first.estaPassandoNoPonto, true);
  });

  test('Filtra paradas espurias, ordena continuamente e limita a 10 paradas', () {
    const embarque = ParadaResumoModel(
      codigoParada: 1,
      nomeParada: 'EMBARQUE',
      endereco: '',
      latitude: -23.5600,
      longitude: -46.6500,
    );
    const desembarque = ParadaResumoModel(
      codigoParada: 99,
      nomeParada: 'DESEMBARQUE',
      endereco: '',
      latitude: -23.5750,
      longitude: -46.6500,
    );
    const espuriaLonge = ParadaResumoModel(
      codigoParada: 999,
      nomeParada: 'ZONA LESTE DISTANTE',
      endereco: '',
      latitude: -23.5400,
      longitude: -46.4500, // > 20km de distancia
    );

    // Gera 14 paradas intermediarias fora de ordem + 1 espuria
    final intermediarias = List.generate(
      14,
      (i) => ParadaResumoModel(
        codigoParada: 10 + i,
        nomeParada: 'PARADA $i',
        endereco: '',
        latitude: -23.5610 - (i * 0.001),
        longitude: -46.6500,
      ),
    ).reversed.toList();

    final resultado = ParadasLinhaFallbackHelper.filtrarEOrdenarCorredor(
      paradas: [...intermediarias, espuriaLonge, desembarque, embarque],
      paradaEmbarque: embarque,
      paradaDesembarque: desembarque,
    );

    expect(resultado.length, 10);
    expect(resultado.first.codigoParada, embarque.codigoParada);
    expect(resultado.last.codigoParada, desembarque.codigoParada);
    expect(resultado.any((p) => p.codigoParada == espuriaLonge.codigoParada), false);

    // Garante ordenacao continua (latitudes decrescentes sem zigue-zague)
    for (int i = 0; i < resultado.length - 1; i++) {
      expect(resultado[i].latitude, greaterThan(resultado[i + 1].latitude));
    }
  });

  test('Formata horario ISO em texto amigavel sem exibir string ISO crua', () {
    const iso = '2026-11-15T20:22:16Z';
    final formatado = PontoMapWidget.formatarHorarioAmigavel(iso);

    expect(formatado.contains('T'), false);
    expect(formatado.contains('Z'), false);
    expect(
      formatado == 'Agora mesmo' || formatado.startsWith('Atualizado às '),
      true,
    );

    expect(
      PontoMapWidget.formatarHorarioAmigavel('14:05:30'),
      'Atualizado às 14:05',
    );
  });

  testWidgets(
      'RoutePlannerScreen inicia com destino vazio e nao dispara busca automatica',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoutePlannerScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica que os dois campos de texto (Partida e Destino) existem
    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.length, 2);
    expect(textFields[0].controller?.text, 'Minha Localização Atual (GPS)');
    expect(textFields[1].controller?.text, isEmpty);

    // Garante que não disparou busca automática
    expect(find.text('Para onde você deseja ir?'), findsOneWidget);
    expect(
      find.text('Calculando rota e consultando linhas disponíveis...'),
      findsNothing,
    );
  });

  test('Parseia letreirosNoPonto e descricaoTrajeto corretamente no model', () {
    final parada = ParadaResumoModel.fromJson({
      'cp': 140016034,
      'np': 'PONTO RUA HEITOR PEIXOTO',
      'ed': 'RUA HEITOR PEIXOTO - CAMBUCI • Ref.: R Heitor Peixoto/ R Basilio Da Cunha',
      'py': -23.5754,
      'px': -46.6187,
      'letreirosNoPonto': ['407M-10', '4111-10'],
    });

    expect(parada.codigoParada, 140016034);
    expect(parada.letreirosNoPonto, ['407M-10', '4111-10']);
    expect(parada.ladoDaViaExplicado, 'Ref.: R Heitor Peixoto/ R Basilio Da Cunha');

    final linha = LinhaPrevisaoModel.fromJson({
      'c': '407M-10',
      'cl': 101,
      'sl': 1,
      'lt0': 'METRÔ VILA MARIANA',
      'lt1': 'LGO. CAMBUCI',
      'qv': 0,
      'vs': [],
    });
    expect(linha.descricaoTrajeto, 'LGO. CAMBUCI ➔ METRÔ VILA MARIANA');
  });

  testWidgets('SptransScreen exibe novos rotulos de Linhas do Ponto e Frota da Linha', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SptransScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('1. Linhas do Ponto'), findsOneWidget);
    expect(find.text('2. Frota da Linha'), findsOneWidget);
  });
}
