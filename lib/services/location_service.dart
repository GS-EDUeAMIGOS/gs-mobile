import 'location_stub.dart'
    if (dart.library.js_interop) 'location_web.dart';

/// Modelo de Posição GPS do Usuário no Dispositivo
class PosicaoUsuarioGps {
  final double latitude;
  final double longitude;
  final bool gpsRealDispositivo;
  final String descricaoOrigem;

  const PosicaoUsuarioGps({
    required this.latitude,
    required this.longitude,
    required this.gpsRealDispositivo,
    required this.descricaoOrigem,
  });
}

/// Camada: Services (Serviço de Geolocalização do Dispositivo)
/// Responsabilidade Única: Capturar a localização GPS atual do celular/navegador do usuário
/// automaticamente ao abrir as telas de Ponto e Rota, permitindo também que o usuário
/// troque ou simule sua posição para testar qualquer região de São Paulo.
class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  PosicaoUsuarioGps? _ultimaPosicao;
  PosicaoUsuarioGps? get ultimaPosicao => _ultimaPosicao;

  /// Obtém a localização atual do aparelho (via GPS W3C no celular/navegador)
  /// ou usa coordenada padrão de São Paulo caso o GPS esteja desativado no computador.
  Future<PosicaoUsuarioGps> obterLocalizacaoAtual({bool forcarAtualizacao = false}) async {
    if (!forcarAtualizacao && _ultimaPosicao != null) {
      return _ultimaPosicao!;
    }

    final nativo = await obterCoordenadasNativas();
    if (nativo != null) {
      // Verifica se a coordenada capturada está dentro da Região Metropolitana de São Paulo
      final dentroDeSp = nativo.latitude >= -24.1 &&
          nativo.latitude <= -23.1 &&
          nativo.longitude >= -47.3 &&
          nativo.longitude <= -46.1;

      if (dentroDeSp) {
        _ultimaPosicao = PosicaoUsuarioGps(
          latitude: nativo.latitude,
          longitude: nativo.longitude,
          gpsRealDispositivo: true,
          descricaoOrigem: 'GPS do seu aparelho',
        );
        return _ultimaPosicao!;
      }
    }

    // Fallback automático caso o usuário esteja testando no PC sem GPS ou fora de SP
    _ultimaPosicao = const PosicaoUsuarioGps(
      latitude: -23.561414,
      longitude: -46.655881,
      gpsRealDispositivo: false,
      descricaoOrigem: 'Localização Automática (Av. Paulista, SP)',
    );
    return _ultimaPosicao!;
  }

  /// Permite definir manualmente uma coordenada GPS (útil para testar em diferentes bairros)
  void definirLocalizacaoManual({
    required double latitude,
    required double longitude,
    required String descricao,
  }) {
    _ultimaPosicao = PosicaoUsuarioGps(
      latitude: latitude,
      longitude: longitude,
      gpsRealDispositivo: false,
      descricaoOrigem: descricao,
    );
  }
}
