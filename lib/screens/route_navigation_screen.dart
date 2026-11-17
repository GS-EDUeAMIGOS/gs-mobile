import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/paradas_linha_fallback_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ponto_map_widget.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Tela 8 — Navegação Ativa / Rota em Tempo Real Estilo Moovit)
/// Responsabilidade Única:
/// 1. Exibir a rota escolhida pelo cidadão em modo "Viagem em Andamento" sem fricção.
/// 2. Listar TODAS as paradas da linha de ônibus selecionada (via `/api/linhas/{codigo}/paradas`).
/// 3. Atualizar automaticamente a posição em tempo real dos ônibus da linha (`/api/linhas/{codigo}/veiculos`)
///    a cada 15 segundos, destacando em qual parada cada ônibus está passando no momento.
class RouteNavigationScreen extends StatefulWidget {
  final OpcaoRotaModel? opcaoInicial;
  final RotaPlanejadaResponseModel? rotaInicial;

  const RouteNavigationScreen({
    super.key,
    this.opcaoInicial,
    this.rotaInicial,
  });

  /// Calcula, para cada parada da linha, quais veículos estão passando nela ou mais próximos dela.
  /// Retorna um mapa `{codigoParada: List<VeiculoNaParadaInfo>}`.
  static Map<int, List<VeiculoNaParadaInfo>> mapearVeiculosNasParadas(
    List<ParadaResumoModel> paradas,
    List<VeiculoPosicaoModel> veiculos,
  ) {
    final resultado = <int, List<VeiculoNaParadaInfo>>{};
    final paradasValidas = paradas.where((p) => p.possuiCoordenadas).toList();
    if (paradasValidas.isEmpty || veiculos.isEmpty) {
      return resultado;
    }

    for (final veiculo in veiculos) {
      if (veiculo.latitude == 0.0 && veiculo.longitude == 0.0) continue;

      ParadaResumoModel? paradaMaisProxima;
      double menorDistancia = double.infinity;

      for (final parada in paradasValidas) {
        final dist = PontoMapWidget.calcularDistanciaMetros(
          parada.latitude,
          parada.longitude,
          veiculo.latitude,
          veiculo.longitude,
        );
        if (dist < menorDistancia) {
          menorDistancia = dist;
          paradaMaisProxima = parada;
        }
      }

      if (paradaMaisProxima != null && menorDistancia <= 1200.0) {
        resultado.putIfAbsent(paradaMaisProxima.codigoParada, () => []).add(
              VeiculoNaParadaInfo(
                veiculo: veiculo,
                distanciaMetros: menorDistancia,
              ),
            );
      }
    }

    return resultado;
  }

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class VeiculoNaParadaInfo {
  final VeiculoPosicaoModel veiculo;
  final double distanciaMetros;

  const VeiculoNaParadaInfo({
    required this.veiculo,
    required this.distanciaMetros,
  });

  bool get estaPassandoNoPonto => distanciaMetros <= 350;
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  static const Duration _intervaloAtualizacao = Duration(seconds: 15);

  OpcaoRotaModel? _opcao;
  RotaPlanejadaResponseModel? _rota;
  List<PassoRotaModel> _passosOnibus = [];
  int _indiceOnibusAtivo = 0;

  bool _initialized = false;
  bool _carregandoParadas = true;
  bool _atualizandoVeiculos = false;
  String? _erroParadas;
  String? _erroVeiculos;

  List<ParadaResumoModel> _paradasDaLinha = [];
  ParadaResumoModel? _paradaSelecionada;
  ParadaResumoModel? _paradaEmbarque;
  ParadaResumoModel? _paradaDesembarque;
  bool _mostrarTodasParadas = false;
  List<VeiculoPosicaoModel> _veiculos = [];
  String _horarioReferencia = '';
  DateTime? _ultimaAtualizacao;

  double? _usuarioLat;
  double? _usuarioLon;

  Timer? _timerTempoReal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (widget.opcaoInicial != null) {
        _opcao = widget.opcaoInicial;
        _rota = widget.rotaInicial;
      } else if (args is Map<String, dynamic>) {
        _opcao = args['opcao'] as OpcaoRotaModel?;
        _rota = args['rota'] as RotaPlanejadaResponseModel?;
      }

      _passosOnibus = (_opcao?.passos ?? [])
          .where(
            (p) =>
                p.codigoLinha > 0 &&
                p.tipoPasso != 'DESEMBARQUE' &&
                p.tipoPasso != 'CAMINHADA',
          )
          .toList();

      _carregarPosicaoUsuario();
      if (_passosOnibus.isNotEmpty) {
        _carregarDadosDaLinha(_passosOnibus.first);
        _iniciarTimerTempoReal();
      } else {
        _carregandoParadas = false;
      }
    }
  }

  @override
  void dispose() {
    _timerTempoReal?.cancel();
    super.dispose();
  }

  void _iniciarTimerTempoReal() {
    _timerTempoReal?.cancel();
    _timerTempoReal = Timer.periodic(_intervaloAtualizacao, (_) {
      if (!mounted || _passosOnibus.isEmpty) return;
      _carregarPosicaoUsuario(forcar: true);
      _atualizarPosicaoVeiculos(_passosOnibus[_indiceOnibusAtivo]);
    });
  }

  Future<void> _carregarPosicaoUsuario({bool forcar = false}) async {
    try {
      final pos = await LocationService.instance.obterLocalizacaoAtual(
        forcarAtualizacao: forcar,
      );
      if (!mounted) return;
      setState(() {
        _usuarioLat = pos.latitude;
        _usuarioLon = pos.longitude;
      });
    } catch (_) {
      // Segue normalmente sem GPS do aparelho
    }
  }

  Future<void> _carregarDadosDaLinha(PassoRotaModel passo) async {
    setState(() {
      _carregandoParadas = true;
      _erroParadas = null;
      _erroVeiculos = null;
      _paradasDaLinha = [];
      _paradaSelecionada = null;
      _paradaEmbarque = null;
      _paradaDesembarque = null;
      _mostrarTodasParadas = false;
      _veiculos = [];
    });

    final termosSentido =
        ParadasLinhaFallbackHelper.extrairTermosLimpos(passo.descricaoSentido);
    final termoHint = termosSentido.isNotEmpty
        ? termosSentido.first
        : (_rota?.localDestinoResolvido?.termoBuscaSptrans ??
            _rota?.localOrigemResolvido?.termoBuscaSptrans);

    try {
      final results = await Future.wait([
        ApiService.instance.buscarParadasPorLinha(
          passo.codigoLinha,
          termo: termoHint,
        ),
        ApiService.instance.buscarVeiculosPorLinha(passo.codigoLinha),
      ]);

      if (!mounted) return;

      final paradasApi = results[0] as List<ParadaResumoModel>;
      final posicao = results[1] as PosicaoLinhaResponseModel;

      // Constrói parada de embarque e desembarque conhecidas na rota caso a SPTrans omita paradas fora de corredor
      ParadaResumoModel? paradaEmbarqueRota = _rota?.paradaOrigemSugerida;
      if (passo.possuiCoordenadasParada) {
        paradaEmbarqueRota = ParadaResumoModel(
          codigoParada: passo.codigoParada ?? 340099001,
          nomeParada: passo.nomeParada ?? passo.local,
          endereco: passo.enderecoParada ?? '',
          latitude: passo.latitudeParada!,
          longitude: passo.longitudeParada!,
        );
      }

      ParadaResumoModel? paradaDesembarqueRota = _rota?.paradaDestinoSugerida;
      if (paradaDesembarqueRota == null &&
          _rota?.localDestinoResolvido != null &&
          _rota!.localDestinoResolvido!.latitude != 0.0) {
        final dest = _rota!.localDestinoResolvido!;
        paradaDesembarqueRota = ParadaResumoModel(
          codigoParada: 340099002,
          nomeParada: 'PARADA ${dest.nomeLocal.toUpperCase()}',
          endereco: dest.enderecoCompleto,
          latitude: dest.latitude,
          longitude: dest.longitude,
        );
      }

      final paradas = await ParadasLinhaFallbackHelper.garantirParadasDaLinha(
        paradasIniciais: paradasApi,
        veiculos: posicao.veiculos,
        descricaoSentido: passo.descricaoSentido,
        letreiroCompleto: passo.letreiroCompleto,
        paradaEmbarque: paradaEmbarqueRota,
        paradaDesembarque: paradaDesembarqueRota,
        paradasProximasOrigem: _rota?.paradasProximasOrigem ?? const [],
      );
      if (!mounted) return;

      // Seleciona sempre a parada de embarque do usuário (ou a mais próxima da origem)
      ParadaResumoModel? embarque;
      final codigoAlvo = passo.codigoParada ?? paradaEmbarqueRota?.codigoParada;
      if (codigoAlvo != null) {
        for (final p in paradas) {
          if (p.codigoParada == codigoAlvo) {
            embarque = p;
            break;
          }
        }
      }

      if (embarque == null && paradas.isNotEmpty) {
        final double? refLat = paradaEmbarqueRota?.possuiCoordenadas == true
            ? paradaEmbarqueRota!.latitude
            : (_rota?.localOrigemResolvido?.latitude != null &&
                    _rota!.localOrigemResolvido!.latitude != 0.0)
                ? _rota!.localOrigemResolvido!.latitude
                : _usuarioLat;
        final double? refLon = paradaEmbarqueRota?.possuiCoordenadas == true
            ? paradaEmbarqueRota!.longitude
            : (_rota?.localOrigemResolvido?.longitude != null &&
                    _rota!.localOrigemResolvido!.longitude != 0.0)
                ? _rota!.localOrigemResolvido!.longitude
                : _usuarioLon;

        if (refLat != null && refLon != null) {
          embarque = paradas.reduce((a, b) {
            final dA = PontoMapWidget.calcularDistanciaMetros(
                refLat, refLon, a.latitude, a.longitude);
            final dB = PontoMapWidget.calcularDistanciaMetros(
                refLat, refLon, b.latitude, b.longitude);
            return dA <= dB ? a : b;
          });
        } else {
          embarque = paradas.first;
        }
      }

      ParadaResumoModel? desembarque;
      final codigoDest = paradaDesembarqueRota?.codigoParada;
      if (codigoDest != null) {
        for (final p in paradas) {
          if (p.codigoParada == codigoDest) {
            desembarque = p;
            break;
          }
        }
      }
      desembarque ??=
          paradas.length > 1 ? paradas.last : paradaDesembarqueRota;

      setState(() {
        _paradasDaLinha = paradas;
        _paradaEmbarque = embarque;
        _paradaDesembarque = desembarque;
        _paradaSelecionada = embarque;
        _veiculos = posicao.veiculos;
        _horarioReferencia = posicao.horarioReferencia;
        _ultimaAtualizacao = DateTime.now();
        _carregandoParadas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroParadas = e.toString().replaceFirst('Exception: ', '');
        _carregandoParadas = false;
      });
    }
  }

  Future<void> _atualizarPosicaoVeiculos(PassoRotaModel passo) async {
    if (_atualizandoVeiculos) return;
    setState(() {
      _atualizandoVeiculos = true;
      _erroVeiculos = null;
    });

    try {
      final posicao = await ApiService.instance.buscarVeiculosPorLinha(
        passo.codigoLinha,
      );
      if (!mounted) return;
      setState(() {
        _veiculos = posicao.veiculos;
        _horarioReferencia = posicao.horarioReferencia;
        _ultimaAtualizacao = DateTime.now();
        _atualizandoVeiculos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroVeiculos = e.toString().replaceFirst('Exception: ', '');
        _atualizandoVeiculos = false;
      });
    }
  }

  void _trocarOnibus(int novoIndice) {
    if (novoIndice == _indiceOnibusAtivo) return;
    setState(() {
      _indiceOnibusAtivo = novoIndice;
    });
    _carregarDadosDaLinha(_passosOnibus[novoIndice]);
  }

  String _formatarHoraAtualizacao() {
    if (_horarioReferencia.isNotEmpty) {
      final amigavel =
          PontoMapWidget.formatarHorarioAmigavel(_horarioReferencia);
      if (amigavel.isNotEmpty) return amigavel;
    }
    if (_ultimaAtualizacao == null) return 'Atualizando...';
    final diffSeg = DateTime.now().difference(_ultimaAtualizacao!).inSeconds.abs();
    if (diffSeg < 60) return 'Agora mesmo';
    final h = _ultimaAtualizacao!.hour.toString().padLeft(2, '0');
    final m = _ultimaAtualizacao!.minute.toString().padLeft(2, '0');
    return 'Atualizado às $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_opcao == null || _passosOnibus.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rota em Andamento'),
          actions: const [ThemeSelectorButton()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_bus_outlined,
                  size: 56,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nenhuma linha de ônibus encontrada nesta rota.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar para Rotas'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final passoAtivo = _passosOnibus[_indiceOnibusAtivo];
    final veiculosPorParada = RouteNavigationScreen.mapearVeiculosNasParadas(
      _paradasDaLinha,
      _veiculos,
    );

    final pinsVeiculos = _veiculos
        .where((v) => v.latitude != 0.0 && v.longitude != 0.0)
        .map(
          (v) => MapaVeiculoPin(
            prefixo: v.prefixo,
            letreiro: passoAtivo.letreiroCompleto,
            acessivelPcD: v.acessivelPcD,
            horarioChegada: v.horarioCaptura.isNotEmpty
                ? PontoMapWidget.formatarHorarioAmigavel(v.horarioCaptura)
                : null,
            latitude: v.latitude,
            longitude: v.longitude,
          ),
        )
        .toList();

    final codigoParadaEmbarque =
        _paradaEmbarque?.codigoParada ?? passoAtivo.codigoParada;
    final codigoParadaDestino = _paradaDesembarque?.codigoParada ??
        _rota?.paradaDestinoSugerida?.codigoParada;

    // Calcula o ônibus mais próximo da parada de embarque
    final paradaRefEmbarque = _paradaEmbarque ?? _paradaSelecionada;
    VeiculoPosicaoModel? onibusMaisProximo;
    double? distOnibusEmbarque;
    if (paradaRefEmbarque != null && paradaRefEmbarque.possuiCoordenadas) {
      for (final v in _veiculos) {
        if (v.latitude == 0.0 && v.longitude == 0.0) continue;
        final d = PontoMapWidget.calcularDistanciaMetros(
          paradaRefEmbarque.latitude,
          paradaRefEmbarque.longitude,
          v.latitude,
          v.longitude,
        );
        if (distOnibusEmbarque == null || d < distOnibusEmbarque) {
          distOnibusEmbarque = d;
          onibusMaisProximo = v;
        }
      }
    }

    // Calcula distância a pé do usuário (ou origem) até o ponto de embarque
    double? distCaminhadaEmbarque;
    final double? origemLat = _usuarioLat ??
        (_rota?.localOrigemResolvido?.latitude != null &&
                _rota!.localOrigemResolvido!.latitude != 0.0
            ? _rota!.localOrigemResolvido!.latitude
            : null);
    final double? origemLon = _usuarioLon ??
        (_rota?.localOrigemResolvido?.longitude != null &&
                _rota!.localOrigemResolvido!.longitude != 0.0
            ? _rota!.localOrigemResolvido!.longitude
            : null);
    if (origemLat != null &&
        origemLon != null &&
        paradaRefEmbarque != null &&
        paradaRefEmbarque.possuiCoordenadas) {
      final d = PontoMapWidget.calcularDistanciaMetros(
        origemLat,
        origemLon,
        paradaRefEmbarque.latitude,
        paradaRefEmbarque.longitude,
      );
      if (d < 20000) {
        distCaminhadaEmbarque = d;
      }
    }

    // Filtra paradas principais (Embarque, Onde o ônibus está agora e Desembarque)
    final List<ParadaResumoModel> paradasChave = [];
    for (int i = 0; i < _paradasDaLinha.length; i++) {
      final p = _paradasDaLinha[i];
      final isEmbarque = i == 0 ||
          (codigoParadaEmbarque != null &&
              p.codigoParada == codigoParadaEmbarque);
      final isDesembarque = i == _paradasDaLinha.length - 1 ||
          (codigoParadaDestino != null &&
              p.codigoParada == codigoParadaDestino);
      final temOnibusAqui =
          (veiculosPorParada[p.codigoParada] ?? const []).isNotEmpty;
      if (isEmbarque || isDesembarque || temOnibusAqui) {
        paradasChave.add(p);
      }
    }
    final List<ParadaResumoModel> paradasExibidas =
        _mostrarTodasParadas || paradasChave.isEmpty
            ? _paradasDaLinha
            : paradasChave;
    final bool temParadasIntermediariasOcultas =
        _paradasDaLinha.length > paradasChave.length && paradasChave.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rota em Andamento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Destino: ${_rota?.destinoBuscado ?? _opcao!.titulo}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          const ThemeSelectorButton(),
          IconButton(
            tooltip: 'Atualizar posição agora',
            onPressed: _atualizandoVeiculos
                ? null
                : () => _atualizarPosicaoVeiculos(passoAtivo),
            icon: _atualizandoVeiculos
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Resumo Compacto da Linha Ativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 9,
                            color: Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AO VIVO • ${_formatarHoraAtualizacao()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '~${_opcao!.tempoEstimadoMinutos} min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Linha ${passoAtivo.letreiroCompleto}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (passoAtivo.descricaoSentido.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    passoAtivo.descricaoSentido,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE0F2FE),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1b. Cards de Status da Viagem (Embarque, Próximo Ônibus, Desembarque)
          _buildStatusCardsViagem(
            passoAtivo: passoAtivo,
            paradaEmbarque: paradaRefEmbarque,
            distCaminhadaEmbarque: distCaminhadaEmbarque,
            onibusMaisProximo: onibusMaisProximo,
            distOnibusEmbarque: distOnibusEmbarque,
            paradaDesembarque: _paradaDesembarque,
          ),
          const SizedBox(height: 12),

          // 2. Seletor de Trecho (quando a rota tem baldeação / 2 ônibus)
          if (_passosOnibus.length > 1) ...[
            Row(
              children: List.generate(_passosOnibus.length, (index) {
                final p = _passosOnibus[index];
                final ativo = index == _indiceOnibusAtivo;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 0 ? 6 : 0,
                      left: index == 1 ? 6 : 0,
                    ),
                    child: ChoiceChip(
                      selected: ativo,
                      onSelected: (_) => _trocarOnibus(index),
                      selectedColor: AppTheme.primaryBlue,
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Ônibus ${index + 1}: ${p.letreiroCompleto}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ativo ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Erro de atualização ao vivo (se houver, sem esconder as paradas)
          if (_erroVeiculos != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                'Não foi possível atualizar a posição ao vivo agora: $_erroVeiculos',
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // 4. Mapa Interativo em Tempo Real (Paradas + Ônibus + Usuário)
          if (!_carregandoParadas &&
              (_paradasDaLinha.isNotEmpty || pinsVeiculos.isNotEmpty)) ...[
            PontoMapWidget(
              paradas: _paradasDaLinha,
              paradasTrajetoLinha: _paradasDaLinha,
              paradaSelecionada: _paradaSelecionada,
              onSelecionarParada: (parada) {
                setState(() {
                  _paradaSelecionada = parada;
                });
              },
              veiculos: pinsVeiculos,
              tituloMapa:
                  'Linha ${passoAtivo.letreiroCompleto}',
              linhaDestacada: passoAtivo.letreiroCompleto,
              usuarioLat: _usuarioLat,
              usuarioLon: _usuarioLon,
              alturaMapa: 340,
              modoNavegacaoSimples: true,
            ),
            const SizedBox(height: 16),
          ],

          // 5. Lista Estilo Moovit com TODAS as Paradas da Linha
          Row(
            children: [
              const Icon(Icons.route, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Paradas da Linha (Ao Vivo)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                'Atualiza a cada 15s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_carregandoParadas)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroParadas != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _erroParadas!,
                      style: const TextStyle(color: AppTheme.dangerRed),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _carregarDadosDaLinha(passoAtivo),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          else if (_paradasDaLinha.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'A SPTrans não retornou a lista detalhada de paradas para este sentido no momento.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    ...List.generate(paradasExibidas.length, (index) {
                      final parada = paradasExibidas[index];
                      final ordemOriginal = _paradasDaLinha.indexWhere(
                            (p) => p.codigoParada == parada.codigoParada,
                          ) +
                          1;
                      final isFirst = index == 0;
                      final isLast = index == paradasExibidas.length - 1;
                      final isEmbarque = codigoParadaEmbarque != null &&
                          parada.codigoParada == codigoParadaEmbarque;
                      final isDesembarque = codigoParadaDestino != null &&
                          parada.codigoParada == codigoParadaDestino;
                      final isSelecionada =
                          _paradaSelecionada?.codigoParada ==
                              parada.codigoParada;
                      final veiculosAqui =
                          veiculosPorParada[parada.codigoParada] ?? const [];

                      return _ParadaTimelineTile(
                        ordem: ordemOriginal > 0 ? ordemOriginal : index + 1,
                        parada: parada,
                        letreiroLinha: passoAtivo.letreiroCompleto,
                        isFirst: isFirst,
                        isLast: isLast,
                        isEmbarque: isEmbarque,
                        isDesembarque: isDesembarque,
                        isSelecionada: isSelecionada,
                        veiculosAqui: veiculosAqui,
                        onTap: () {
                          setState(() {
                            _paradaSelecionada = parada;
                          });
                        },
                      );
                    }),
                    if (temParadasIntermediariasOcultas) ...[
                      const Divider(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _mostrarTodasParadas = !_mostrarTodasParadas;
                            });
                          },
                          icon: Icon(
                            _mostrarTodasParadas
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _mostrarTodasParadas
                                ? 'Ocultar paradas intermediárias'
                                : 'Mostrar todas as ${_paradasDaLinha.length} paradas',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 18),

          // 6. Botão simples para encerrar a rota
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Encerrar Rota'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.dangerRed,
                side: const BorderSide(color: AppTheme.dangerRed),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusCardsViagem({
    required PassoRotaModel passoAtivo,
    required ParadaResumoModel? paradaEmbarque,
    required double? distCaminhadaEmbarque,
    required VeiculoPosicaoModel? onibusMaisProximo,
    required double? distOnibusEmbarque,
    required ParadaResumoModel? paradaDesembarque,
  }) {
    final nomeEmbarque = paradaEmbarque?.nomeParada ??
        passoAtivo.nomeParada ??
        passoAtivo.local;

    final String subEmbarque;
    if (distCaminhadaEmbarque != null) {
      if (distCaminhadaEmbarque <= 85) {
        subEmbarque = 'Você já está neste ponto (${distCaminhadaEmbarque.round()} m)';
      } else {
        final minPe = math.max(1, (distCaminhadaEmbarque / 75).ceil());
        final distFmt = distCaminhadaEmbarque < 1000
            ? '${distCaminhadaEmbarque.round()} m'
            : '${(distCaminhadaEmbarque / 1000).toStringAsFixed(1)} km';
        subEmbarque = 'a $distFmt • ~$minPe min a pé';
      }
    } else {
      subEmbarque = 'Ponto inicial da sua viagem';
    }

    final String tituloOnibus;
    final String subOnibus;
    Widget? badgeOnibus;

    if (onibusMaisProximo != null && distOnibusEmbarque != null) {
      tituloOnibus = 'Linha ${passoAtivo.letreiroCompleto}';
      final String distFmt;
      if (distOnibusEmbarque <= 150) {
        distFmt = 'Chegando';
      } else if (distOnibusEmbarque < 1000) {
        distFmt = 'a ${distOnibusEmbarque.round()} m';
      } else {
        distFmt = 'a ${(distOnibusEmbarque / 1000).toStringAsFixed(1)} km';
      }
      final minBus = math.max(1, (distOnibusEmbarque / 300).ceil());
      subOnibus = '$distFmt do embarque • ~$minBus min';
      badgeOnibus = _BadgeTag(
        text: onibusMaisProximo.acessivelPcD
            ? 'Acessível PcD ♿'
            : 'Sem elevador',
        bgColor: onibusMaisProximo.acessivelPcD
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF3C7),
        textColor: onibusMaisProximo.acessivelPcD
            ? const Color(0xFF166534)
            : const Color(0xFFB45309),
      );
    } else {
      tituloOnibus = 'Aguardando ônibus';
      subOnibus = passoAtivo.previsaoChegada.isNotEmpty
          ? passoAtivo.previsaoChegada
          : 'Sem ônibus com GPS no momento';
    }

    final nomeDesembarque = paradaDesembarque?.nomeParada ??
        _rota?.destinoBuscado ??
        _opcao!.titulo;

    return Column(
      children: [
        _StatusViagemCard(
          titulo: 'Seu Embarque',
          valorPrincipal: nomeEmbarque,
          subtitulo: subEmbarque,
          icone: Icons.hail_rounded,
          corDestaque: AppTheme.primaryBlue,
          corFundoIcone: const Color(0xFFDBEAFE),
        ),
        const SizedBox(height: 8),
        _StatusViagemCard(
          titulo: 'Próximo Ônibus',
          valorPrincipal: tituloOnibus,
          subtitulo: subOnibus,
          icone: Icons.directions_bus_rounded,
          corDestaque: onibusMaisProximo?.acessivelPcD == true
              ? const Color(0xFF059669)
              : AppTheme.secondaryTeal,
          corFundoIcone: onibusMaisProximo?.acessivelPcD == true
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFCCFBF1),
          trailingBadge: badgeOnibus,
        ),
        const SizedBox(height: 8),
        _StatusViagemCard(
          titulo: 'Seu Desembarque',
          valorPrincipal: nomeDesembarque,
          subtitulo: 'Destino final deste trecho',
          icone: Icons.flag_rounded,
          corDestaque: const Color(0xFFD97706),
          corFundoIcone: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }
}

class _ParadaTimelineTile extends StatelessWidget {
  final int ordem;
  final ParadaResumoModel parada;
  final String letreiroLinha;
  final bool isFirst;
  final bool isLast;
  final bool isEmbarque;
  final bool isDesembarque;
  final bool isSelecionada;
  final List<VeiculoNaParadaInfo> veiculosAqui;
  final VoidCallback onTap;

  const _ParadaTimelineTile({
    required this.ordem,
    required this.parada,
    required this.letreiroLinha,
    required this.isFirst,
    required this.isLast,
    required this.isEmbarque,
    required this.isDesembarque,
    required this.isSelecionada,
    required this.veiculosAqui,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final temOnibus = veiculosAqui.isNotEmpty;
    final Color dotColor = temOnibus
        ? AppTheme.secondaryTeal
        : isEmbarque
            ? AppTheme.primaryBlue
            : isDesembarque
                ? const Color(0xFFD97706)
                : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelecionada
              ? Theme.of(context).colorScheme.primaryContainer
              : temOnibus
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trilho vertical estilo Moovit
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isFirst
                            ? Colors.transparent
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    Container(
                      width: temOnibus ? 22 : 16,
                      height: temOnibus ? 22 : 16,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: temOnibus
                            ? [
                                BoxShadow(
                                  color: AppTheme.secondaryTeal.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: temOnibus
                          ? const Icon(
                              Icons.directions_bus,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isLast
                            ? Colors.transparent
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Conteúdo da parada
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$ordem',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parada.nomeParada,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: (isEmbarque ||
                                        isDesembarque ||
                                        temOnibus)
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (parada.endereco.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          parada.endereco,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if (isEmbarque || isDesembarque || temOnibus) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isEmbarque)
                              _BadgeTag(
                                text: 'SEU EMBARQUE',
                                bgColor: const Color(0xFFDBEAFE),
                                textColor: AppTheme.primaryBlue,
                              ),
                            if (isDesembarque)
                              const _BadgeTag(
                                text: 'SEU DESEMBARQUE',
                                bgColor: Color(0xFFFEF3C7),
                                textColor: Color(0xFFB45309),
                              ),
                            ...veiculosAqui.map((info) {
                              final dist = info.distanciaMetros.round();
                              final label = info.estaPassandoNoPonto
                                  ? '🚌 Linha $letreiroLinha passando aqui ($dist m)'
                                  : '🚌 Linha $letreiroLinha próximo ($dist m)';
                              return _BadgeTag(
                                text: info.veiculo.acessivelPcD
                                    ? '$label • ♿'
                                    : label,
                                bgColor: const Color(0xFFDCFCE7),
                                textColor: const Color(0xFF166534),
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTag extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _BadgeTag({
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _StatusViagemCard extends StatelessWidget {
  final String titulo;
  final String valorPrincipal;
  final String subtitulo;
  final IconData icone;
  final Color corDestaque;
  final Color corFundoIcone;
  final Widget? trailingBadge;

  const _StatusViagemCard({
    required this.titulo,
    required this.valorPrincipal,
    required this.subtitulo,
    required this.icone,
    required this.corDestaque,
    required this.corFundoIcone,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isProximoOnibus = titulo == 'Próximo Ônibus';
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isProximoOnibus ? 14 : 12,
        vertical: isProximoOnibus ? 13 : 10,
      ),
      decoration: BoxDecoration(
        color: isProximoOnibus
            ? colors.secondaryContainer.withValues(alpha: 0.55)
            : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isProximoOnibus
              ? corDestaque.withValues(alpha: 0.55)
              : colors.outlineVariant,
          width: isProximoOnibus ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: corFundoIcone,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: corDestaque, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: corDestaque,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valorPrincipal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (trailingBadge != null) ...[
            const SizedBox(width: 8),
            trailingBadge!,
          ],
        ],
      ),
    );
  }
}
