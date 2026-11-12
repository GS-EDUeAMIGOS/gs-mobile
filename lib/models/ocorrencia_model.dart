/// Camada: Models (Domínio / DTOs de Ocorrências Cidadãs)
/// Responsabilidade Única: Espelhar os Enums (`TipoOcorrencia`, `StatusOcorrencia`, `NivelGravidade`)
/// e a classe `OcorrenciaDTO` do backend Java, fazendo a tradução entre JSON e objetos Dart.

enum TipoOcorrencia {
  ACESSIBILIDADE('Acessibilidade Geral'),
  ELEVADOR_INOPERANTE('Elevador PcD Inoperante'),
  LOTACAO_EXCESSIVA('Lotação Excessiva'),
  ATRASO('Atraso Crítico'),
  SEGURANCA('Segurança'),
  INFRAESTRUTURA_PARADA('Infraestrutura da Parada'),
  OUTROS('Outros');

  final String label;
  const TipoOcorrencia(this.label);

  static TipoOcorrencia fromString(String? value) {
    return TipoOcorrencia.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TipoOcorrencia.OUTROS,
    );
  }
}

enum StatusOcorrencia {
  ABERTA('Aberta'),
  EM_ANALISE('Em Análise'),
  CONFIRMADA('Confirmada'),
  RESOLVIDA('Resolvida'),
  ARQUIVADA('Arquivada');

  final String label;
  const StatusOcorrencia(this.label);

  static StatusOcorrencia fromString(String? value) {
    return StatusOcorrencia.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StatusOcorrencia.ABERTA,
    );
  }
}

enum NivelGravidade {
  BAIXA('Baixa'),
  MEDIA('Média'),
  ALTA('Alta'),
  CRITICA('Crítica');

  final String label;
  const NivelGravidade(this.label);

  static NivelGravidade fromString(String? value) {
    return NivelGravidade.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NivelGravidade.MEDIA,
    );
  }
}

class OcorrenciaModel {
  final int? id;
  final int usuarioId;
  final String? nomeUsuario;
  final String titulo;
  final String descricao;
  final TipoOcorrencia tipo;
  final StatusOcorrencia status;
  final NivelGravidade gravidade;
  final int? codigoLinha;
  final int? codigoParada;
  final String? prefixoVeiculo;
  final bool afetaAcessibilidade;
  final String? criadoEm;

  const OcorrenciaModel({
    this.id,
    required this.usuarioId,
    this.nomeUsuario,
    required this.titulo,
    required this.descricao,
    required this.tipo,
    this.status = StatusOcorrencia.ABERTA,
    this.gravidade = NivelGravidade.MEDIA,
    this.codigoLinha,
    this.codigoParada,
    this.prefixoVeiculo,
    this.afetaAcessibilidade = false,
    this.criadoEm,
  });

  /// Converte o JSON de resposta (`OcorrenciaDTO.Response`) do Java para o modelo Dart
  factory OcorrenciaModel.fromJson(Map<String, dynamic> json) {
    return OcorrenciaModel(
      id: (json['id'] as num?)?.toInt(),
      usuarioId: (json['usuarioId'] as num?)?.toInt() ?? 0,
      nomeUsuario: json['nomeUsuario'] as String?,
      titulo: json['titulo'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      tipo: TipoOcorrencia.fromString(json['tipo'] as String?),
      status: StatusOcorrencia.fromString(json['status'] as String?),
      gravidade: NivelGravidade.fromString(json['gravidade'] as String?),
      codigoLinha: (json['codigoLinha'] as num?)?.toInt(),
      codigoParada: (json['codigoParada'] as num?)?.toInt(),
      prefixoVeiculo: json['prefixoVeiculo'] as String?,
      afetaAcessibilidade: json['afetaAcessibilidade'] as bool? ?? false,
      criadoEm: json['criadoEm'] as String?,
    );
  }

  /// Converte o objeto Dart em um Map JSON compatível com `OcorrenciaDTO.Request` do Java
  Map<String, dynamic> toJson() {
    return {
      'usuarioId': usuarioId,
      'titulo': titulo,
      'descricao': descricao,
      'tipo': tipo.name,
      'status': status.name,
      'gravidade': gravidade.name,
      if (codigoLinha != null) 'codigoLinha': codigoLinha,
      if (codigoParada != null) 'codigoParada': codigoParada,
      if (prefixoVeiculo != null && prefixoVeiculo!.isNotEmpty)
        'prefixoVeiculo': prefixoVeiculo,
      'afetaAcessibilidade': afetaAcessibilidade,
    };
  }
}
