// Camada: Models (Domínio / DTOs da SPTrans Olho Vivo)
// Responsabilidade Única: Mapear o retorno dos endpoints `/api/linhas`, `/api/linhas/{codigo}/veiculos`
// e `/api/paradas` que utilizam as chaves oficiais da SPTrans (`cl`, `lt`, `tp`, `ts`, `vs`, `p`, `a`, etc.).

class LinhaResumoModel {
  final int codigoLinha;
  final bool circular;
  final String letreiroNumerico;
  final int modoAtendimento;
  final int sentido;
  final String terminalPrincipal;
  final String terminalSecundario;

  const LinhaResumoModel({
    required this.codigoLinha,
    required this.circular,
    required this.letreiroNumerico,
    required this.modoAtendimento,
    required this.sentido,
    required this.terminalPrincipal,
    required this.terminalSecundario,
  });

  factory LinhaResumoModel.fromJson(Map<String, dynamic> json) {
    return LinhaResumoModel(
      codigoLinha: (json['cl'] as num?)?.toInt() ?? 0,
      circular: json['lc'] as bool? ?? false,
      letreiroNumerico: json['lt'] as String? ?? '',
      modoAtendimento: (json['tl'] as num?)?.toInt() ?? 10,
      sentido: (json['sl'] as num?)?.toInt() ?? 1,
      terminalPrincipal: json['tp'] as String? ?? '',
      terminalSecundario: json['ts'] as String? ?? '',
    );
  }

  String get letreiroCompleto => '$letreiroNumerico-$modoAtendimento';

  String get descricaoSentido =>
      sentido == 1 ? '$terminalPrincipal ➔ $terminalSecundario' : '$terminalSecundario ➔ $terminalPrincipal';
}

class VeiculoPosicaoModel {
  final String prefixo;
  final bool acessivelPcD;
  final String horarioCaptura;
  final double latitude;
  final double longitude;

  const VeiculoPosicaoModel({
    required this.prefixo,
    required this.acessivelPcD,
    required this.horarioCaptura,
    required this.latitude,
    required this.longitude,
  });

  factory VeiculoPosicaoModel.fromJson(Map<String, dynamic> json) {
    return VeiculoPosicaoModel(
      prefixo: json['p']?.toString() ?? '',
      acessivelPcD: json['a'] as bool? ?? false,
      horarioCaptura: json['ta'] as String? ?? '',
      latitude: (json['py'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['px'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PosicaoLinhaResponseModel {
  final String horarioReferencia;
  final List<VeiculoPosicaoModel> veiculos;

  const PosicaoLinhaResponseModel({
    required this.horarioReferencia,
    required this.veiculos,
  });

  factory PosicaoLinhaResponseModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['vs'] as List<dynamic>? ?? [];
    return PosicaoLinhaResponseModel(
      horarioReferencia: json['hr'] as String? ?? '',
      veiculos: rawList
          .map((item) => VeiculoPosicaoModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ParadaResumoModel {
  final int codigoParada;
  final String nomeParada;
  final String endereco;
  final double latitude;
  final double longitude;

  const ParadaResumoModel({
    required this.codigoParada,
    required this.nomeParada,
    required this.endereco,
    required this.latitude,
    required this.longitude,
  });

  factory ParadaResumoModel.fromJson(Map<String, dynamic> json) {
    return ParadaResumoModel(
      codigoParada: (json['cp'] as num?)?.toInt() ?? 0,
      nomeParada: json['np'] as String? ?? '',
      endereco: json['ed'] as String? ?? '',
      latitude: (json['py'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['px'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get possuiCoordenadas => latitude != 0.0 && longitude != 0.0;

  /// Traduz siglas técnicas da SPTrans (ex.: B/C e C/B) para linguagem cidadã clara
  String get ladoDaViaExplicado {
    final upper = nomeParada.toUpperCase();
    if (upper.contains('B/C')) {
      return 'Lado Bairro ➔ Centro (B/C)';
    }
    if (upper.contains('C/B')) {
      return 'Lado Centro ➔ Bairro (C/B)';
    }
    return 'Parada Oficial SPTrans';
  }
}

class VeiculoPrevisaoModel {
  final String prefixo;
  final String horarioPrevistoChegada;
  final bool acessivelPcD;
  final String horarioCaptura;
  final double latitude;
  final double longitude;

  const VeiculoPrevisaoModel({
    required this.prefixo,
    required this.horarioPrevistoChegada,
    required this.acessivelPcD,
    required this.horarioCaptura,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory VeiculoPrevisaoModel.fromJson(Map<String, dynamic> json) {
    return VeiculoPrevisaoModel(
      prefixo: json['p']?.toString() ?? '',
      horarioPrevistoChegada: json['t'] as String? ?? '',
      acessivelPcD: json['a'] as bool? ?? false,
      horarioCaptura: json['ta'] as String? ?? '',
      latitude: (json['py'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['px'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get possuiCoordenadas => latitude != 0.0 && longitude != 0.0;
}

class LinhaPrevisaoModel {
  final String letreiroCompleto;
  final int codigoLinha;
  final int sentido;
  final String destino;
  final String origem;
  final int quantidadeVeiculos;
  final List<VeiculoPrevisaoModel> veiculos;

  const LinhaPrevisaoModel({
    required this.letreiroCompleto,
    required this.codigoLinha,
    required this.sentido,
    required this.destino,
    required this.origem,
    required this.quantidadeVeiculos,
    required this.veiculos,
  });

  factory LinhaPrevisaoModel.fromJson(Map<String, dynamic> json) {
    final rawVs = json['vs'] as List<dynamic>? ?? [];
    return LinhaPrevisaoModel(
      letreiroCompleto: json['c'] as String? ?? '',
      codigoLinha: (json['cl'] as num?)?.toInt() ?? 0,
      sentido: (json['sl'] as num?)?.toInt() ?? 1,
      destino: json['lt0'] as String? ?? '',
      origem: json['lt1'] as String? ?? '',
      quantidadeVeiculos: (json['qv'] as num?)?.toInt() ?? 0,
      veiculos: rawVs
          .map((v) => VeiculoPrevisaoModel.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ParadaComPrevisoesModel {
  final int codigoParada;
  final String nomeParada;
  final double latitude;
  final double longitude;
  final List<LinhaPrevisaoModel> linhas;

  const ParadaComPrevisoesModel({
    required this.codigoParada,
    required this.nomeParada,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.linhas,
  });

  factory ParadaComPrevisoesModel.fromJson(Map<String, dynamic> json) {
    final rawLinhas = json['l'] as List<dynamic>? ?? [];
    return ParadaComPrevisoesModel(
      codigoParada: (json['cp'] as num?)?.toInt() ?? 0,
      nomeParada: json['np'] as String? ?? '',
      latitude: (json['py'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['px'] as num?)?.toDouble() ?? 0.0,
      linhas: rawLinhas
          .map((l) => LinhaPrevisaoModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PrevisaoParadaResponseModel {
  final String horarioReferencia;
  final ParadaComPrevisoesModel? parada;

  const PrevisaoParadaResponseModel({
    required this.horarioReferencia,
    this.parada,
  });

  factory PrevisaoParadaResponseModel.fromJson(Map<String, dynamic> json) {
    final pJson = json['p'] as Map<String, dynamic>?;
    return PrevisaoParadaResponseModel(
      horarioReferencia: json['hr'] as String? ?? '',
      parada: pJson != null ? ParadaComPrevisoesModel.fromJson(pJson) : null,
    );
  }
}

// =============================================================================
// Modelos de Geolocalização, Locais Reais (Hospitais, Shoppings) e Planejador
// =============================================================================

class LocalResolvidoModel {
  final String termoOriginal;
  final String nomeLocal;
  final String enderecoCompleto;
  final String logradouro;
  final String bairro;
  final String termoBuscaSptrans;
  final double latitude;
  final double longitude;

  const LocalResolvidoModel({
    required this.termoOriginal,
    required this.nomeLocal,
    required this.enderecoCompleto,
    required this.logradouro,
    required this.bairro,
    required this.termoBuscaSptrans,
    required this.latitude,
    required this.longitude,
  });

  factory LocalResolvidoModel.fromJson(Map<String, dynamic> json) {
    return LocalResolvidoModel(
      termoOriginal: json['termoOriginal'] as String? ?? '',
      nomeLocal: json['nomeLocal'] as String? ?? '',
      enderecoCompleto: json['enderecoCompleto'] as String? ?? '',
      logradouro: json['logradouro'] as String? ?? '',
      bairro: json['bairro'] as String? ?? '',
      termoBuscaSptrans: json['termoBuscaSptrans'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ParadasProximasGpsResponseModel {
  final LocalResolvidoModel? localAtual;
  final ParadaResumoModel? paradaMaisProxima;
  final int distanciaAtePontoMaisProximoMetros;
  final int tempoCaminhadaMinutos;
  final bool usuarioEstaNoPonto;
  final String mensagemProximidade;
  final List<ParadaResumoModel> paradasProximas;

  const ParadasProximasGpsResponseModel({
    this.localAtual,
    this.paradaMaisProxima,
    required this.distanciaAtePontoMaisProximoMetros,
    required this.tempoCaminhadaMinutos,
    required this.usuarioEstaNoPonto,
    required this.mensagemProximidade,
    required this.paradasProximas,
  });

  factory ParadasProximasGpsResponseModel.fromJson(Map<String, dynamic> json) {
    final rawParadas = json['paradasProximas'] as List<dynamic>? ?? [];
    final lAtual = json['localAtual'] as Map<String, dynamic>?;
    final pProx = json['paradaMaisProxima'] as Map<String, dynamic>?;
    return ParadasProximasGpsResponseModel(
      localAtual: lAtual != null ? LocalResolvidoModel.fromJson(lAtual) : null,
      paradaMaisProxima: pProx != null ? ParadaResumoModel.fromJson(pProx) : null,
      distanciaAtePontoMaisProximoMetros:
          (json['distanciaAtePontoMaisProximoMetros'] as num?)?.toInt() ?? 0,
      tempoCaminhadaMinutos: (json['tempoCaminhadaMinutos'] as num?)?.toInt() ?? 1,
      usuarioEstaNoPonto: json['usuarioEstaNoPonto'] as bool? ?? false,
      mensagemProximidade: json['mensagemProximidade'] as String? ?? '',
      paradasProximas: rawParadas
          .map((p) => ParadaResumoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PassoRotaModel {
  final int ordem;
  final String tipoPasso;
  final String instrucao;
  final String local;
  final int? distanciaCaminhadaMetros;
  final int? tempoCaminhadaMinutos;
  final int? codigoParada;
  final String? nomeParada;
  final String? enderecoParada;
  final double? latitudeParada;
  final double? longitudeParada;
  final bool pontoConfirmadoNaParada;
  final int codigoLinha;
  final String letreiroCompleto;
  final String descricaoSentido;
  final int veiculosCirculando;
  final int veiculosAcessiveisPcD;
  final String? proximoPrefixo;
  final double? latitudeProximoVeiculo;
  final double? longitudeProximoVeiculo;
  final String previsaoChegada;
  final int ocorrenciasAbertas;
  final String? alertaComunidade;

  const PassoRotaModel({
    required this.ordem,
    required this.tipoPasso,
    required this.instrucao,
    required this.local,
    this.distanciaCaminhadaMetros,
    this.tempoCaminhadaMinutos,
    this.codigoParada,
    this.nomeParada,
    this.enderecoParada,
    this.latitudeParada,
    this.longitudeParada,
    this.pontoConfirmadoNaParada = false,
    required this.codigoLinha,
    required this.letreiroCompleto,
    required this.descricaoSentido,
    required this.veiculosCirculando,
    required this.veiculosAcessiveisPcD,
    this.proximoPrefixo,
    this.latitudeProximoVeiculo,
    this.longitudeProximoVeiculo,
    required this.previsaoChegada,
    required this.ocorrenciasAbertas,
    this.alertaComunidade,
  });

  bool get possuiCoordenadasParada =>
      latitudeParada != null &&
      longitudeParada != null &&
      latitudeParada != 0.0 &&
      longitudeParada != 0.0;

  bool get possuiCoordenadasVeiculo =>
      latitudeProximoVeiculo != null &&
      longitudeProximoVeiculo != null &&
      latitudeProximoVeiculo != 0.0 &&
      longitudeProximoVeiculo != 0.0;

  factory PassoRotaModel.fromJson(Map<String, dynamic> json) {
    return PassoRotaModel(
      ordem: (json['ordem'] as num?)?.toInt() ?? 1,
      tipoPasso: json['tipoPasso'] as String? ?? 'EMBARQUE',
      instrucao: json['instrucao'] as String? ?? '',
      local: json['local'] as String? ?? '',
      distanciaCaminhadaMetros: (json['distanciaCaminhadaMetros'] as num?)?.toInt(),
      tempoCaminhadaMinutos: (json['tempoCaminhadaMinutos'] as num?)?.toInt(),
      codigoParada: (json['codigoParada'] as num?)?.toInt(),
      nomeParada: json['nomeParada'] as String?,
      enderecoParada: json['enderecoParada'] as String?,
      latitudeParada: (json['latitudeParada'] as num?)?.toDouble(),
      longitudeParada: (json['longitudeParada'] as num?)?.toDouble(),
      pontoConfirmadoNaParada: json['pontoConfirmadoNaParada'] as bool? ?? false,
      codigoLinha: (json['codigoLinha'] as num?)?.toInt() ?? 0,
      letreiroCompleto: json['letreiroCompleto'] as String? ?? '',
      descricaoSentido: json['descricaoSentido'] as String? ?? '',
      veiculosCirculando: (json['veiculosCirculando'] as num?)?.toInt() ?? 0,
      veiculosAcessiveisPcD: (json['veiculosAcessiveisPcD'] as num?)?.toInt() ?? 0,
      proximoPrefixo: json['proximoPrefixo']?.toString(),
      latitudeProximoVeiculo: (json['latitudeProximoVeiculo'] as num?)?.toDouble(),
      longitudeProximoVeiculo: (json['longitudeProximoVeiculo'] as num?)?.toDouble(),
      previsaoChegada: json['previsaoChegada'] as String? ?? '',
      ocorrenciasAbertas: (json['ocorrenciasAbertas'] as num?)?.toInt() ?? 0,
      alertaComunidade: json['alertaComunidade'] as String?,
    );
  }
}

class OpcaoRotaModel {
  final String titulo;
  final String tipoRota;
  final bool recomendada;
  final String motivoRecomendacao;
  final int totalOnibusNecessarios;
  final int tempoEstimadoMinutos;
  final bool totalmenteAcessivelPcD;
  final int totalOcorrenciasNoTrajeto;
  final List<PassoRotaModel> passos;

  const OpcaoRotaModel({
    required this.titulo,
    required this.tipoRota,
    required this.recomendada,
    required this.motivoRecomendacao,
    required this.totalOnibusNecessarios,
    required this.tempoEstimadoMinutos,
    required this.totalmenteAcessivelPcD,
    required this.totalOcorrenciasNoTrajeto,
    required this.passos,
  });

  factory OpcaoRotaModel.fromJson(Map<String, dynamic> json) {
    final rawPassos = json['passos'] as List<dynamic>? ?? [];
    return OpcaoRotaModel(
      titulo: json['titulo'] as String? ?? '',
      tipoRota: json['tipoRota'] as String? ?? 'DIRETA',
      recomendada: json['recomendada'] as bool? ?? false,
      motivoRecomendacao: json['motivoRecomendacao'] as String? ?? '',
      totalOnibusNecessarios: (json['totalOnibusNecessarios'] as num?)?.toInt() ?? 1,
      tempoEstimadoMinutos: (json['tempoEstimadoMinutos'] as num?)?.toInt() ?? 30,
      totalmenteAcessivelPcD: json['totalmenteAcessivelPcD'] as bool? ?? false,
      totalOcorrenciasNoTrajeto: (json['totalOcorrenciasNoTrajeto'] as num?)?.toInt() ?? 0,
      passos: rawPassos
          .map((p) => PassoRotaModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RotaPlanejadaResponseModel {
  final String origemBuscada;
  final String destinoBuscado;
  final String horarioConsulta;
  final LocalResolvidoModel? localOrigemResolvido;
  final LocalResolvidoModel? localDestinoResolvido;
  final int distanciaCaminhadaOrigemMetros;
  final int distanciaCaminhadaDestinoMetros;
  final ParadaResumoModel? paradaOrigemSugerida;
  final ParadaResumoModel? paradaDestinoSugerida;
  final List<ParadaResumoModel> paradasProximasOrigem;
  final List<OpcaoRotaModel> opcoes;

  const RotaPlanejadaResponseModel({
    required this.origemBuscada,
    required this.destinoBuscado,
    required this.horarioConsulta,
    this.localOrigemResolvido,
    this.localDestinoResolvido,
    this.distanciaCaminhadaOrigemMetros = 0,
    this.distanciaCaminhadaDestinoMetros = 0,
    this.paradaOrigemSugerida,
    this.paradaDestinoSugerida,
    this.paradasProximasOrigem = const [],
    required this.opcoes,
  });

  factory RotaPlanejadaResponseModel.fromJson(Map<String, dynamic> json) {
    final rawOpcoes = json['opcoes'] as List<dynamic>? ?? [];
    final rawParadasOrigem = json['paradasProximasOrigem'] as List<dynamic>? ?? [];
    final lOrig = json['localOrigemResolvido'] as Map<String, dynamic>?;
    final lDest = json['localDestinoResolvido'] as Map<String, dynamic>?;
    final pOrig = json['paradaOrigemSugerida'] as Map<String, dynamic>?;
    final pDest = json['paradaDestinoSugerida'] as Map<String, dynamic>?;
    return RotaPlanejadaResponseModel(
      origemBuscada: json['origemBuscada'] as String? ?? '',
      destinoBuscado: json['destinoBuscado'] as String? ?? '',
      horarioConsulta: json['horarioConsulta'] as String? ?? '',
      localOrigemResolvido: lOrig != null ? LocalResolvidoModel.fromJson(lOrig) : null,
      localDestinoResolvido: lDest != null ? LocalResolvidoModel.fromJson(lDest) : null,
      distanciaCaminhadaOrigemMetros:
          (json['distanciaCaminhadaOrigemMetros'] as num?)?.toInt() ?? 0,
      distanciaCaminhadaDestinoMetros:
          (json['distanciaCaminhadaDestinoMetros'] as num?)?.toInt() ?? 0,
      paradaOrigemSugerida: pOrig != null ? ParadaResumoModel.fromJson(pOrig) : null,
      paradaDestinoSugerida: pDest != null ? ParadaResumoModel.fromJson(pDest) : null,
      paradasProximasOrigem: rawParadasOrigem
          .map((p) => ParadaResumoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      opcoes: rawOpcoes
          .map((o) => OpcaoRotaModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}
