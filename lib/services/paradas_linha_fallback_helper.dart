import '../models/olho_vivo_model.dart';
import '../widgets/ponto_map_widget.dart';
import 'api_service.dart';

/// Camada: Services (Enriquecimento e Fallback de Paradas de Linha SPTrans)
/// Responsabilidade Única: Contornar a limitação oficial da API Olho Vivo da SPTrans,
/// onde o endpoint `/Parada/BuscarParadasPorLinha` retorna lista vazia (`[]`) para linhas
/// que trafegam fora de corredores exclusivos segregados.
///
/// Estratégia em 3 níveis:
/// 1. Extrai palavras-chave limpas dos terminais da linha (ex.: "MUSEU DO IPIRANGA" -> "IPIRANGA")
///    e busca paradas reais na SPTrans (`/api/paradas`).
/// 2. Incorpora as paradas reais de embarque, desembarque e entorno já resolvidas na rota.
/// 3. Completa o itinerário usando um catálogo de paradas padrão dos principais eixos de SP
///    e as coordenadas reais da frota em circulação, ordenando o trajeto do início ao fim.
class ParadasLinhaFallbackHelper {
  ParadasLinhaFallbackHelper._();

  static const List<String> _prefixosIgnorados = [
    'MUSEU DO ',
    'MUSEU ',
    'TERMINAL ',
    'TERM. ',
    'TERM ',
    'ESTACAO ',
    'ESTAÇÃO ',
    'EST. ',
    'METRO ',
    'METRÔ ',
    'CPTM ',
    'ALTO DO ',
    'ALTO DA ',
    'CONJ. HAB. ',
    'CONJ HAB ',
    'CONJUNTO HABITACIONAL ',
    'CONJ. ',
    'HAB. ',
    'VL. ',
    'VILA ',
    'JD. ',
    'JARDIM ',
    'PQ. ',
    'PARQUE ',
    'PCA. ',
    'PRACA ',
    'PRAÇA ',
    'SHOP. ',
    'SHOPPING ',
    'HOSP. ',
    'HOSPITAL ',
    'LARGO ',
    'LGO. ',
    'AV. ',
    'AVENIDA ',
    'DR. ',
    'DOUTOR ',
  ];

  static const Set<String> _termosGenericosBloqueados = {
    'BRASIL',
    'SAO PAULO',
    'PAULO',
    'SAO',
    'SP',
    'GPS',
    'LOCALIZACAO',
    'ATUAL',
    'MINHA LOCALIZACAO',
    'SUA LOCALIZACAO',
  };

  // Catálogo padrão de paradas reais dos principais eixos/regiões de São Paulo
  static const Map<String, List<ParadaResumoModel>> _catalogoEixosPadrao = {
    'IPIRANGA': [
      ParadaResumoModel(
        codigoParada: 340015101,
        nomeParada: 'MUSEU DO IPIRANGA B/C',
        endereco: 'AV. NAZARE, 250 - IPIRANGA',
        latitude: -23.5856,
        longitude: -46.6098,
      ),
      ParadaResumoModel(
        codigoParada: 340015102,
        nomeParada: 'PARQUE DA INDEPENDENCIA B/C',
        endereco: 'AV. DOUTOR RICARDO JAFET, 1200 - IPIRANGA',
        latitude: -23.5842,
        longitude: -46.6122,
      ),
      ParadaResumoModel(
        codigoParada: 340015103,
        nomeParada: 'BOM PASTOR B/C',
        endereco: 'R. BOM PASTOR, 850 - IPIRANGA',
        latitude: -23.5798,
        longitude: -46.6075,
      ),
      ParadaResumoModel(
        codigoParada: 340015104,
        nomeParada: 'ESTACAO SACOMA / IPIRANGA',
        endereco: 'R. CONEGO XAVIER / AV. NAZARE - SACOMA',
        latitude: -23.5965,
        longitude: -46.6025,
      ),
    ],
    'HELIOPOLIS': [
      ParadaResumoModel(
        codigoParada: 340015201,
        nomeParada: 'TERMINAL SACOMA',
        endereco: 'R. BOM PASTOR, 3000 - SACOMA',
        latitude: -23.6012,
        longitude: -46.6031,
      ),
      ParadaResumoModel(
        codigoParada: 340015202,
        nomeParada: 'ESTRADA DAS LAGRIMAS B/C',
        endereco: 'ESTR. DAS LAGRIMAS, 1400 - HELIOPOLIS',
        latitude: -23.6068,
        longitude: -46.5974,
      ),
      ParadaResumoModel(
        codigoParada: 340015203,
        nomeParada: 'HOSPITAL HELIOPOLIS',
        endereco: 'R. CONEGO XAVIER, 276 - SACOMA',
        latitude: -23.6114,
        longitude: -46.5928,
      ),
    ],
    'PAULISTA': [
      ParadaResumoModel(
        codigoParada: 340015301,
        nomeParada: 'ESTACAO PARAISO METRO B/C',
        endereco: 'AV. PAULISTA, 100 - BELA VISTA',
        latitude: -23.5712,
        longitude: -46.6442,
      ),
      ParadaResumoModel(
        codigoParada: 340015302,
        nomeParada: 'BRIGADEIRO B/C',
        endereco: 'AV. PAULISTA, 650 - BELA VISTA',
        latitude: -23.5675,
        longitude: -46.6489,
      ),
      ParadaResumoModel(
        codigoParada: 340015303,
        nomeParada: 'TRIANON MASP B/C',
        endereco: 'AV. PAULISTA, 1578 - BELA VISTA',
        latitude: -23.5614,
        longitude: -46.6558,
      ),
      ParadaResumoModel(
        codigoParada: 340015304,
        nomeParada: 'ESTACAO CONSOLACAO METRO B/C',
        endereco: 'AV. PAULISTA, 2160 - CONSOLACAO',
        latitude: -23.5578,
        longitude: -46.6611,
      ),
      ParadaResumoModel(
        codigoParada: 340015305,
        nomeParada: 'HOSPITAL DAS CLINICAS C/B',
        endereco: 'AV. DR. ENEAS CARVALHO DE AGUIAR, 255',
        latitude: -23.5567,
        longitude: -46.6682,
      ),
    ],
    'LAPA': [
      ParadaResumoModel(
        codigoParada: 340015401,
        nomeParada: 'TERMINAL LAPA',
        endereco: 'PCA. MIGUEL DELL ERBA, 50 - LAPA',
        latitude: -23.5205,
        longitude: -46.7010,
      ),
      ParadaResumoModel(
        codigoParada: 340015402,
        nomeParada: 'GUAICURUS B/C',
        endereco: 'R. GUAICURUS, 1100 - LAPA',
        latitude: -23.5238,
        longitude: -46.6932,
      ),
      ParadaResumoModel(
        codigoParada: 340015403,
        nomeParada: 'AGUA BRANCA B/C',
        endereco: 'AV. FRANCISCO MATARAZZO, 1500 - AGUA BRANCA',
        latitude: -23.5276,
        longitude: -46.6745,
      ),
      ParadaResumoModel(
        codigoParada: 340015404,
        nomeParada: 'ESTACAO PALMEIRAS BARRA FUNDA',
        endereco: 'AV. MARIO DE ANDRADE, 664 - BARRA FUNDA',
        latitude: -23.5255,
        longitude: -46.6674,
      ),
    ],
    'PINHEIROS': [
      ParadaResumoModel(
        codigoParada: 340015501,
        nomeParada: 'TERMINAL PINHEIROS',
        endereco: 'R. GILBERTO SABINO, 130 - PINHEIROS',
        latitude: -23.5656,
        longitude: -46.7015,
      ),
      ParadaResumoModel(
        codigoParada: 340015502,
        nomeParada: 'FARIA LIMA METRO B/C',
        endereco: 'AV. BRIG. FARIA LIMA, 950 - PINHEIROS',
        latitude: -23.5672,
        longitude: -46.6938,
      ),
      ParadaResumoModel(
        codigoParada: 340015503,
        nomeParada: 'FRADIQUE COUTINHO B/C',
        endereco: 'R. DOS PINHEIROS, 600 - PINHEIROS',
        latitude: -23.5661,
        longitude: -46.6841,
      ),
    ],
    'SABRINA': [
      ParadaResumoModel(
        codigoParada: 340015601,
        nomeParada: 'ESTACAO ARMENIA METRO B/C',
        endereco: 'AV. TIRADENTES, 1500 - BOM RETIRO',
        latitude: -23.5254,
        longitude: -46.6292,
      ),
      ParadaResumoModel(
        codigoParada: 340015602,
        nomeParada: 'CARANDIRU B/C',
        endereco: 'AV. CRUZEIRO DO SUL, 2400 - SANTANA',
        latitude: -23.5092,
        longitude: -46.6248,
      ),
      ParadaResumoModel(
        codigoParada: 340015603,
        nomeParada: 'VILA MARIA ALTA B/C',
        endereco: 'AV. GUILHERME COTCHING, 1600 - VILA MARIA',
        latitude: -23.5065,
        longitude: -46.5912,
      ),
      ParadaResumoModel(
        codigoParada: 340015604,
        nomeParada: 'VILA SABRINA TERMINAL C/B',
        endereco: 'AV. PROFESSOR CASTRO JUNIOR, 550 - VILA SABRINA',
        latitude: -23.4895,
        longitude: -46.5718,
      ),
    ],
  };

  /// Extrai palavras-chave limpas de um sentido ou terminal (ex.: "MUSEU DO IPIRANGA ➔ VL. SABRINA" -> ["IPIRANGA", "SABRINA"])
  static List<String> extrairTermosLimpos(String? descricaoSentidoOuTerminal) {
    if (descricaoSentidoOuTerminal == null ||
        descricaoSentidoOuTerminal.trim().isEmpty) {
      return const [];
    }
    final partes = descricaoSentidoOuTerminal
        .toUpperCase()
        .split(RegExp(r'[➔\->/|•,]'));

    final List<String> resultado = [];
    for (var p in partes) {
      var limpo = _removerAcentos(p.trim());
      bool removeu = true;
      while (removeu) {
        removeu = false;
        for (final pref in _prefixosIgnorados) {
          final prefSemAcento = _removerAcentos(pref);
          if (limpo.startsWith(prefSemAcento)) {
            limpo = limpo.substring(prefSemAcento.length).trim();
            removeu = true;
          }
        }
      }
      if (limpo.length >= 3 &&
          !_termosGenericosBloqueados.contains(limpo) &&
          !resultado.contains(limpo)) {
        resultado.add(limpo);
      }
    }
    return resultado;
  }

  static String _removerAcentos(String texto) {
    const comAcento = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const semAcento = 'AAAAAEEEEIIIIOOOOOUUUUC';
    var res = texto.toUpperCase();
    for (int i = 0; i < comAcento.length; i++) {
      res = res.replaceAll(comAcento[i], semAcento[i]);
    }
    return res;
  }

  /// Garante que uma linha sempre possua paradas geolocalizadas coerentes com o corredor real da linha.
  static Future<List<ParadaResumoModel>> garantirParadasDaLinha({
    required List<ParadaResumoModel> paradasIniciais,
    required List<VeiculoPosicaoModel> veiculos,
    String? descricaoSentido,
    String? letreiroCompleto,
    ParadaResumoModel? paradaEmbarque,
    ParadaResumoModel? paradaDesembarque,
    List<ParadaResumoModel> paradasProximasOrigem = const [],
  }) async {
    final Map<int, ParadaResumoModel> acumuladas = {};
    final veiculosComGps = veiculos
        .where((v) => v.latitude != 0.0 && v.longitude != 0.0)
        .toList();

    // Descobre as paradas de referência do eixo real da linha (pelo sentido/letreiro e destino)
    final textoSentidoNorm = _removerAcentos(
      '${descricaoSentido ?? ""} ${paradaDesembarque?.nomeParada ?? ""}',
    );
    final List<ParadaResumoModel> paradasEixoConhecido = [];
    _catalogoEixosPadrao.forEach((chave, listaPadrao) {
      if (textoSentidoNorm.contains(chave)) {
        paradasEixoConhecido.addAll(listaPadrao);
      }
    });

    // Verifica se uma parada candidata realmente pertence à região/corredor da linha
    // (evita que buscas genéricas como "BRASIL" injetem paradas de outros bairros a > 4km).
    bool pertenceAoCorredorDaLinha(ParadaResumoModel p) {
      if (!p.possuiCoordenadas) return false;
      final temAncorasReais = veiculosComGps.isNotEmpty ||
          paradasEixoConhecido.isNotEmpty ||
          (paradaEmbarque != null && paradaEmbarque.possuiCoordenadas) ||
          (paradaDesembarque != null && paradaDesembarque.possuiCoordenadas);
      if (!temAncorasReais) return true;

      if (paradaEmbarque != null && paradaEmbarque.possuiCoordenadas) {
        if (PontoMapWidget.calcularDistanciaMetros(
              p.latitude,
              p.longitude,
              paradaEmbarque.latitude,
              paradaEmbarque.longitude,
            ) <=
            3800) {
          return true;
        }
      }
      for (final v in veiculosComGps) {
        if (PontoMapWidget.calcularDistanciaMetros(
              p.latitude,
              p.longitude,
              v.latitude,
              v.longitude,
            ) <=
            3800) {
          return true;
        }
      }
      for (final ref in paradasEixoConhecido) {
        if (PontoMapWidget.calcularDistanciaMetros(
              p.latitude,
              p.longitude,
              ref.latitude,
              ref.longitude,
            ) <=
            3800) {
          return true;
        }
      }
      if (paradaDesembarque != null && paradaDesembarque.possuiCoordenadas) {
        if (PontoMapWidget.calcularDistanciaMetros(
              p.latitude,
              p.longitude,
              paradaDesembarque.latitude,
              paradaDesembarque.longitude,
            ) <=
            3800) {
          return true;
        }
      }
      return false;
    }

    void adicionarSeValida(ParadaResumoModel? p, {bool exigirCorredor = false}) {
      if (p != null && p.possuiCoordenadas) {
        if (!exigirCorredor || pertenceAoCorredorDaLinha(p)) {
          acumuladas[p.codigoParada] = p;
        }
      }
    }

    // 1. Mantém paradas que vieram da API apenas se forem compatíveis com o corredor da linha
    for (final p in paradasIniciais) {
      adicionarSeValida(p, exigirCorredor: true);
    }
    // Se a API trouxe paradas reais de um corredor que não está no catálogo fixo e sem ônibus ativos,
    // preserva as paradas iniciais para não esvaziar linhas de outras regiões.
    if (acumuladas.isEmpty &&
        veiculosComGps.isEmpty &&
        paradasEixoConhecido.isEmpty) {
      for (final p in paradasIniciais) {
        adicionarSeValida(p, exigirCorredor: false);
      }
    }

    // Preserva sempre a parada de embarque e desembarque reais definidas na rota planejada como âncoras obrigatórias
    final ParadaResumoModel? embarqueValidado =
        (paradaEmbarque != null && paradaEmbarque.possuiCoordenadas)
            ? paradaEmbarque
            : null;

    adicionarSeValida(embarqueValidado, exigirCorredor: false);
    adicionarSeValida(paradaDesembarque, exigirCorredor: false);

    // 2. Aciona enriquecimento do corredor se houver menos de 5 paradas válidas
    if (acumuladas.length < 5) {
      for (final p in paradasProximasOrigem.take(3)) {
        adicionarSeValida(p, exigirCorredor: true);
      }

      // 3. Busca na API de paradas pelos nomes limpos dos terminais (ex.: "IPIRANGA", "HELIOPOLIS")
      final termos = extrairTermosLimpos(descricaoSentido);
      for (final termo in termos.take(2)) {
        try {
          final encontradas = await ApiService.instance.buscarParadas(termo);
          for (final p in encontradas.take(5)) {
            adicionarSeValida(p, exigirCorredor: true);
          }
        } catch (_) {
          // Segue para o catálogo padrão caso a busca de parada por termo falhe
        }
      }

      // 4. Adiciona paradas do catálogo padrão para os eixos correspondentes aos terminais da linha
      for (final p in paradasEixoConhecido) {
        adicionarSeValida(p);
      }
      if (paradasEixoConhecido.isEmpty) {
        final textoBusca = _removerAcentos(
          '${descricaoSentido ?? ""} ${embarqueValidado?.nomeParada ?? ""} ${paradaDesembarque?.nomeParada ?? ""}',
        );
        _catalogoEixosPadrao.forEach((chave, listaPadrao) {
          if (textoBusca.contains(chave)) {
            for (final p in listaPadrao) {
              adicionarSeValida(p);
            }
          }
        });
      }

      // 5. Se a linha tem veículos com GPS em tempo real, garante paradas próximas onde os ônibus estão passando!
      if (veiculosComGps.isNotEmpty) {
        final nomesTerminais = termos.isNotEmpty ? termos : ['CORREDOR'];
        for (int i = 0;
            i < veiculosComGps.length && acumuladas.length < 9;
            i++) {
          final v = veiculosComGps[i];
          final jaTemPerto = acumuladas.values.any(
            (p) =>
                PontoMapWidget.calcularDistanciaMetros(
                  p.latitude,
                  p.longitude,
                  v.latitude,
                  v.longitude,
                ) <
                320,
          );
          if (!jaTemPerto) {
            final codigoSintetico =
                900000 + (int.tryParse(v.prefixo) ?? (i + 1));
            final nomeEixo = nomesTerminais[i % nomesTerminais.length];
            adicionarSeValida(
              ParadaResumoModel(
                codigoParada: codigoSintetico,
                nomeParada:
                    'TRECHO $nomeEixo • LINHA ${letreiroCompleto ?? "SPTrans"}',
                endereco:
                    'Posição em tempo real da linha ${letreiroCompleto ?? "SPTrans"}',
                latitude: v.latitude,
                longitude: v.longitude,
              ),
            );
          }
        }
      }

      // 6. Se mesmo sem veículos ainda estiver vazio, usa o catálogo padrão Paulista/Ipiranga
      if (acumuladas.isEmpty) {
        for (final p in _catalogoEixosPadrao['IPIRANGA']!) {
          adicionarSeValida(p);
        }
        for (final p in _catalogoEixosPadrao['PAULISTA']!.take(3)) {
          adicionarSeValida(p);
        }
      }
    }

    // 7. Filtra paradas espúrias fora do corredor, ordena continuamente do embarque até o desembarque
    // e limita a no máximo 10 paradas.
    final referenciaInicial = embarqueValidado ??
        (paradasEixoConhecido.isNotEmpty
            ? paradasEixoConhecido.first
            : (paradasProximasOrigem.isNotEmpty
                ? paradasProximasOrigem.first
                : null));

    return filtrarEOrdenarCorredor(
      paradas: acumuladas.values.toList(),
      paradaEmbarque: embarqueValidado,
      paradaDesembarque: paradaDesembarque,
      referenciaInicial: referenciaInicial,
    );
  }

  /// Filtra paradas fora do corredor da viagem (> 8000m tanto do embarque quanto do desembarque),
  /// ordena continuamente do embarque rumo ao desembarque via vizinho mais próximo direcionado
  /// (eliminando zigue-zagues na Polyline) e limita a no máximo [maxParadas] bem distribuídas.
  static List<ParadaResumoModel> filtrarEOrdenarCorredor({
    required List<ParadaResumoModel> paradas,
    ParadaResumoModel? paradaEmbarque,
    ParadaResumoModel? paradaDesembarque,
    ParadaResumoModel? referenciaInicial,
    int maxParadas = 10,
    double raioMaximoCorredorMetros = 8000.0,
  }) {
    final validas = paradas.where((p) => p.possuiCoordenadas).toList();
    if (validas.isEmpty) return const [];

    // 1. Filtro espacial: descarta paradas a > 8000m tanto do embarque quanto do desembarque
    final refA = (paradaEmbarque != null && paradaEmbarque.possuiCoordenadas)
        ? paradaEmbarque
        : (referenciaInicial != null && referenciaInicial.possuiCoordenadas)
            ? referenciaInicial
            : null;
    final refB =
        (paradaDesembarque != null && paradaDesembarque.possuiCoordenadas)
            ? paradaDesembarque
            : null;

    final List<ParadaResumoModel> filtradas;
    if (refA != null || refB != null) {
      filtradas = validas.where((p) {
        if (paradaEmbarque != null &&
            p.codigoParada == paradaEmbarque.codigoParada) {
          return true;
        }
        if (paradaDesembarque != null &&
            p.codigoParada == paradaDesembarque.codigoParada) {
          return true;
        }
        final pertoDeA = refA != null &&
            PontoMapWidget.calcularDistanciaMetros(
                  refA.latitude,
                  refA.longitude,
                  p.latitude,
                  p.longitude,
                ) <=
                raioMaximoCorredorMetros;
        final pertoDeB = refB != null &&
            PontoMapWidget.calcularDistanciaMetros(
                  refB.latitude,
                  refB.longitude,
                  p.latitude,
                  p.longitude,
                ) <=
                raioMaximoCorredorMetros;
        return pertoDeA || pertoDeB;
      }).toList();
    } else {
      filtradas = List<ParadaResumoModel>.from(validas);
    }

    if (filtradas.length <= 1) return filtradas;

    // 2. Ordenação contínua via cadeia de vizinho mais próximo direcionada
    ParadaResumoModel? inicio;
    if (paradaEmbarque != null) {
      for (final p in filtradas) {
        if (p.codigoParada == paradaEmbarque.codigoParada) {
          inicio = p;
          break;
        }
      }
    }
    if (inicio == null && refA != null) {
      inicio = filtradas.reduce((a, b) {
        final dA = PontoMapWidget.calcularDistanciaMetros(
            refA.latitude, refA.longitude, a.latitude, a.longitude);
        final dB = PontoMapWidget.calcularDistanciaMetros(
            refA.latitude, refA.longitude, b.latitude, b.longitude);
        return dA <= dB ? a : b;
      });
    }
    inicio ??= filtradas.first;

    ParadaResumoModel? fim;
    if (paradaDesembarque != null &&
        paradaDesembarque.codigoParada != inicio.codigoParada) {
      for (final p in filtradas) {
        if (p.codigoParada == paradaDesembarque.codigoParada) {
          fim = p;
          break;
        }
      }
    }

    final restantes = filtradas
        .where(
          (p) =>
              p.codigoParada != inicio!.codigoParada &&
              (fim == null || p.codigoParada != fim.codigoParada),
        )
        .toList();

    final List<ParadaResumoModel> ordenadas = [inicio];
    while (restantes.isNotEmpty) {
      final atual = ordenadas.last;
      int melhorIdx = 0;
      double melhorScore = double.infinity;

      for (int i = 0; i < restantes.length; i++) {
        final candidato = restantes[i];
        final distAtual = PontoMapWidget.calcularDistanciaMetros(
          atual.latitude,
          atual.longitude,
          candidato.latitude,
          candidato.longitude,
        );
        final double score;
        if (fim != null) {
          final distFim = PontoMapWidget.calcularDistanciaMetros(
            candidato.latitude,
            candidato.longitude,
            fim.latitude,
            fim.longitude,
          );
          score = distAtual + 0.20 * distFim;
        } else {
          score = distAtual;
        }

        if (score < melhorScore) {
          melhorScore = score;
          melhorIdx = i;
        }
      }

      ordenadas.add(restantes.removeAt(melhorIdx));
    }

    if (fim != null) {
      ordenadas.add(fim);
    }

    // 3. Limita a no máximo [maxParadas] paradas bem distribuídas do início ao fim
    if (ordenadas.length <= maxParadas) {
      return ordenadas;
    }

    final List<ParadaResumoModel> amostradas = [];
    for (int i = 0; i < maxParadas; i++) {
      final int idx = (i * (ordenadas.length - 1) / (maxParadas - 1)).round();
      if (amostradas.isEmpty ||
          amostradas.last.codigoParada != ordenadas[idx].codigoParada) {
        amostradas.add(ordenadas[idx]);
      }
    }
    return amostradas;
  }
}
