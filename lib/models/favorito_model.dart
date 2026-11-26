/// Camada: Models (Domínio / DTOs de Favoritos)
/// Responsabilidade Única: Representar as paradas e linhas favoritas do cidadão
/// retornadas pelos endpoints `/api/paradas-favoritas` e `/api/linhas-favoritas`
/// da API REST Java (`ParadaFavoritaDTO.Response` e `LinhaFavoritaDTO.Response`).
class ParadaFavoritaModel {
  final int id;
  final int usuarioId;
  final int codigoParada;
  final String nomeParada;
  final String? endereco;
  final double? latitude;
  final double? longitude;
  final bool possuiRampaAcessivel;
  final bool possuiPisoTatil;
  final String? criadoEm;

  const ParadaFavoritaModel({
    required this.id,
    required this.usuarioId,
    required this.codigoParada,
    required this.nomeParada,
    this.endereco,
    this.latitude,
    this.longitude,
    this.possuiRampaAcessivel = false,
    this.possuiPisoTatil = false,
    this.criadoEm,
  });

  /// Factory Constructor: Converte um Map (JSON vindo da API Java) em objeto Dart tipado.
  factory ParadaFavoritaModel.fromJson(Map<String, dynamic> json) {
    return ParadaFavoritaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      usuarioId: (json['usuarioId'] as num?)?.toInt() ?? 0,
      codigoParada: (json['codigoParada'] as num?)?.toInt() ?? 0,
      nomeParada: json['nomeParada'] as String? ?? 'Parada sem nome',
      endereco: json['endereco'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      possuiRampaAcessivel: json['possuiRampaAcessivel'] as bool? ?? false,
      possuiPisoTatil: json['possuiPisoTatil'] as bool? ?? false,
      criadoEm: json['criadoEm'] as String?,
    );
  }

  /// Indica se a parada possui pelo menos um recurso de acessibilidade registrado.
  bool get isAcessivel => possuiRampaAcessivel || possuiPisoTatil;
}

class LinhaFavoritaModel {
  final int id;
  final int usuarioId;
  final int codigoLinha;
  final String letreiro;
  final int sentido;
  final String? terminalOrigem;
  final String? terminalDestino;
  final String? apelido;
  final String? criadoEm;

  const LinhaFavoritaModel({
    required this.id,
    required this.usuarioId,
    required this.codigoLinha,
    required this.letreiro,
    required this.sentido,
    this.terminalOrigem,
    this.terminalDestino,
    this.apelido,
    this.criadoEm,
  });

  /// Factory Constructor: Converte um Map (JSON vindo da API Java) em objeto Dart tipado.
  factory LinhaFavoritaModel.fromJson(Map<String, dynamic> json) {
    return LinhaFavoritaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      usuarioId: (json['usuarioId'] as num?)?.toInt() ?? 0,
      codigoLinha: (json['codigoLinha'] as num?)?.toInt() ?? 0,
      letreiro: json['letreiro'] as String? ?? '',
      sentido: (json['sentido'] as num?)?.toInt() ?? 1,
      terminalOrigem: json['terminalOrigem'] as String?,
      terminalDestino: json['terminalDestino'] as String?,
      apelido: json['apelido'] as String?,
      criadoEm: json['criadoEm'] as String?,
    );
  }

  /// Descrição amigável do trajeto entre os terminais (quando informados).
  String get descricaoTrajeto {
    final origem = terminalOrigem?.trim() ?? '';
    final destino = terminalDestino?.trim() ?? '';
    if (origem.isNotEmpty && destino.isNotEmpty) {
      return '$origem ➔ $destino';
    }
    if (origem.isNotEmpty) return 'Origem: $origem';
    if (destino.isNotEmpty) return 'Destino: $destino';
    return sentido == 1 ? 'Sentido Principal (Ida)' : 'Sentido Secundário (Volta)';
  }
}
