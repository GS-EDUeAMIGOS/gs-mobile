import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/models/olho_vivo_model.dart';
import 'package:viacidada_mobile/services/paradas_linha_fallback_helper.dart';
import 'package:viacidada_mobile/theme/map_theme.dart';
import 'package:viacidada_mobile/widgets/map/stop_marker_widget.dart';
import 'package:viacidada_mobile/widgets/ponto_map_widget.dart';

void main() {
  const paradaComum1 = ParadaResumoModel(
    codigoParada: 1001,
    nomeParada: 'TRIANON MASP B/C',
    endereco: 'AV PAULISTA, 1500',
    latitude: -23.5614,
    longitude: -46.6558,
  );

  const paradaComum2 = ParadaResumoModel(
    codigoParada: 1002,
    nomeParada: 'CONSOLACAO C/B',
    endereco: 'AV PAULISTA, 2000',
    latitude: -23.5582,
    longitude: -46.6602,
  );

  const paradaComum3 = ParadaResumoModel(
    codigoParada: 1003,
    nomeParada: 'PAMPLONA B/C',
    endereco: 'AV PAULISTA, 1200',
    latitude: -23.5625,
    longitude: -46.6540,
  );

  const terminalParada = ParadaResumoModel(
    codigoParada: 2001,
    nomeParada: 'TERMINAL LAPA',
    endereco: 'PRACA MIGUEL DELL ERBA',
    latitude: -23.5205,
    longitude: -46.7010,
  );

  const estacaoMetro = ParadaResumoModel(
    codigoParada: 2002,
    nomeParada: 'ESTAÇÃO CONSOLAÇÃO METRÔ',
    endereco: 'AV PAULISTA, 2100',
    latitude: -23.5578,
    longitude: -46.6611,
  );

  const onibusPcd = MapaVeiculoPin(
    prefixo: '81234',
    letreiro: '875A-10',
    acessivelPcD: true,
    horarioChegada: '14:35',
    latitude: -23.5605,
    longitude: -46.6570,
  );

  const onibusComum = MapaVeiculoPin(
    prefixo: '89999',
    letreiro: '6450-10',
    acessivelPcD: false,
    horarioChegada: '14:42',
    latitude: -23.5620,
    longitude: -46.6550,
  );

  test('Identifica corretamente Terminais e Estacoes de Metro/CPTM', () {
    expect(MapTheme.isTerminalOuEstacao(terminalParada), true);
    expect(MapTheme.isTerminalOuEstacao(estacaoMetro), true);
    expect(MapTheme.isTerminalOuEstacao(paradaComum1), false);
    expect(MapTheme.extrairSiglaLadoVia(paradaComum1), 'B/C');
    expect(MapTheme.extrairSiglaLadoVia(paradaComum2), 'C/B');
  });

  test('Agrupa paradas comuns em clusters no zoom <= 14 mantendo Terminais fora', () {
    final grupos = StopClusterHelper.agruparParadas(
      paradas: [paradaComum1, paradaComum2, paradaComum3, terminalParada],
      zoom: 13.0,
      codigoParadaSelecionada: paradaComum1.codigoParada,
    );

    // paradaComum1 é selecionada e terminalParada é Terminal -> ambos ficam fora do cluster.
    // paradaComum2 e paradaComum3 estão próximos no raio de zoom 13 (~900m) -> agrupados.
    expect(grupos.length, 1);
    expect(grupos.first.isCluster, true);
    expect(grupos.first.quantidade, 2);
  });

  testWidgets('Renderiza PontoMapWidget Dark Transit UI com filtros e sem erro offline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PontoMapWidget(
              paradas: [paradaComum1, paradaComum2, estacaoMetro],
              paradasTrajetoLinha: [paradaComum1, paradaComum2, estacaoMetro],
              paradaSelecionada: paradaComum1,
              veiculos: [onibusPcd, onibusComum],
              usuarioLat: -23.5610,
              usuarioLon: -46.6562,
              linhaDestacada: '875A-10',
              linhaPassaNestePonto: true,
            ),
          ),
        ),
      ),
    );

    // Avança alguns frames sem depender de pumpAndSettle por causa do pulso contínuo de GPS
    await tester.pump(const Duration(milliseconds: 200));

    // Cabeçalho, faixa de caminhada até o ponto e confirmação da linha
    expect(find.textContaining('PONTO CONFIRMADO'), findsOneWidget);
    expect(find.text('VOCÊ'), findsOneWidget);
    expect(find.text('SEU PONTO'), findsOneWidget);
    expect(find.textContaining('está a'), findsOneWidget);
    expect(find.textContaining('Ônibus nº'), findsNothing);

    // Chips de filtros de camada no mapa
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Terminais'), findsOneWidget);
    expect(find.text('Ônibus'), findsOneWidget);
    expect(find.text('Só PcD ♿'), findsOneWidget);
    expect(find.text('Trajeto/Linha'), findsOneWidget);

    // Ambos os ônibus (PcD e comum) aparecem inicialmente exibindo o letreiro da linha
    expect(find.text('875A-10'), findsOneWidget);
    expect(find.text('6450-10'), findsOneWidget);

    // Ativa o filtro "Só PcD ♿" -> oculta ônibus comum (6450-10) e mantém PcD (875A-10)
    await tester.tap(find.text('Só PcD ♿'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('875A-10'), findsOneWidget);
    expect(find.text('6450-10'), findsNothing);

    // Toca no ônibus PcD (875A-10) para abrir o card inspetor interno
    await tester.tap(find.text('875A-10'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Com Elevador PcD (Acessível)'), findsOneWidget);
  });

  testWidgets('Alterna entre Tema Escuro (OSM Dark Matrix) e Tema Claro (OSM)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PontoMapWidget(
              paradas: [paradaComum1],
              paradaSelecionada: paradaComum1,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('tile_osm_dark_fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_osm_light')), findsNothing);

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('tile_osm_light')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_osm_dark_fallback')), findsNothing);
  });

  testWidgets('Interpola posicao dos onibus ao atualizar veiculos sem quebrar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PontoMapWidget(
              paradas: [paradaComum1],
              paradaSelecionada: paradaComum1,
              veiculos: [onibusPcd],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    const onibusPcdMovido = MapaVeiculoPin(
      prefixo: '81234',
      letreiro: '875A-10',
      acessivelPcD: true,
      horarioChegada: '14:36',
      latitude: -23.5610,
      longitude: -46.6563,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PontoMapWidget(
              paradas: [paradaComum1],
              paradaSelecionada: paradaComum1,
              veiculos: [onibusPcdMovido],
            ),
          ),
        ),
      ),
    );

    // Avança a animação de interpolação (1000ms) sem falhar
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('875A-10'), findsOneWidget);
  });

  test('Garante paradas padrao do trajeto quando SPTrans retorna lista vazia para linha fora de corredor',
      () async {
    const veiculoLinha174M = VeiculoPosicaoModel(
      prefixo: '22280',
      acessivelPcD: true,
      horarioCaptura: '14:44',
      latitude: -23.5845,
      longitude: -46.6115,
    );

    final paradas = await ParadasLinhaFallbackHelper.garantirParadasDaLinha(
      paradasIniciais: const [],
      veiculos: const [veiculoLinha174M],
      descricaoSentido: 'MUSEU DO IPIRANGA ➔ VL. SABRINA',
      letreiroCompleto: '174M-10',
    );

    expect(paradas, isNotEmpty);
    expect(paradas.length, greaterThanOrEqualTo(4));
    expect(
      paradas.any((p) => p.nomeParada.contains('IPIRANGA')),
      true,
    );
  });
}
