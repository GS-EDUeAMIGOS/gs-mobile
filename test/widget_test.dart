import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/main.dart';
import 'package:viacidada_mobile/models/olho_vivo_model.dart';
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

    expect(paradaBC.ladoDaViaExplicado, 'Lado Bairro ➔ Centro (B/C)');
    expect(paradaCB.ladoDaViaExplicado, 'Lado Centro ➔ Bairro (C/B)');

    final distancia = PontoMapWidget.calcularDistanciaMetros(
      paradaBC.latitude,
      paradaBC.longitude,
      paradaCB.latitude,
      paradaCB.longitude,
    );
    expect(distancia, greaterThan(10));
    expect(distancia, lessThan(100));
  });
}
