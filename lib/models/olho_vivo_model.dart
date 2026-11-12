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
