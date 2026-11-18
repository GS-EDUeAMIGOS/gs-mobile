import 'dart:async';
import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/paradas_linha_fallback_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/ponto_map_widget.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Tela 6 — Radar SPTrans Olho Vivo em Tempo Real com Mapa Dark Transit UI)
/// Responsabilidade Única: Oferecer ao cidadão uma experiência estilo Moovit com mapa
/// interativo em destaque, painel eletrônico deslizante de previsões de chegada,
/// verificação do lado da via (B/C vs C/B), trajeto completo da linha e fiscalização PcD.
class SptransScreen extends StatefulWidget {
  const SptransScreen({super.key});

  @override
  State<SptransScreen> createState() => _SptransScreenState();
}

class _SptransScreenState extends State<SptransScreen> {
  static const Duration _intervaloAtualizacao = Duration(seconds: 15);

  // 0 = Estou no Ponto (Mapa do Ponto + Previsão de Chegada + Verificador de Linha)
  // 1 = Buscar por Linha (Mapa da Frota na Rua + Trajeto/Polyline + Pontos da Linha)
  int _abaSelecionada = 0;

  // Modo Moovit (mapa amplo em destaque + painel deslizante) vs Modo Clássico (lista + card)
  bool _modoMapaExpandido = true;

  // Atualização automática em tempo real a cada 15s (opcional, controlável pelo usuário)
  bool _atualizacaoAutomatica = true;
  bool _atualizandoSilenciosamente = false;
  DateTime? _ultimaAtualizacao;
  Timer? _timerTempoReal;

  // Estado da Aba 0: Paradas, GPS do Celular, Mapa e Previsão de Chegada no Ponto
  final _termoParadaController = TextEditingController(text: 'PAULISTA');
  final _filtroLinhaNoPontoController = TextEditingController();
  PosicaoUsuarioGps? _posicaoGps;
  String? _mensagemGpsPonto;
  bool? _usuarioEstaNoPonto;
  List<ParadaResumoModel> _paradas = [];
  ParadaResumoModel? _paradaSelecionada;
  PrevisaoParadaResponseModel? _previsaoParada;
  bool _isLoadingParadas = false;
  bool _isLoadingPrevisao = false;

  // Estado da Aba 1: Linhas, Frota na Rua e Paradas da Linha
  final _termoLinhaController = TextEditingController(text: '8000');
  List<LinhaResumoModel> _linhas = [];
  LinhaResumoModel? _linhaSelecionada;
  int? _codigoLinhaAvulso;
  PosicaoLinhaResponseModel? _posicaoAtual;
  List<ParadaResumoModel> _paradasDaLinha = [];
  ParadaResumoModel? _paradaDaLinhaSelecionada;
  bool _isLoadingLinhas = false;
  bool _isLoadingVeiculos = false;
  String _ultimoTermoLinha = '8000';

  String? _errorMessage;
  bool _initializedArgs = false;

  @override
  void initState() {
    super.initState();
    _iniciarTimerTempoReal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _abaSelecionada = 1;
        _codigoLinhaAvulso = args;
        _buscarLinhas(selecionarCodigoAutomatico: args);
        _buscarParadas();
      } else if (args is Map<String, dynamic>) {
        _abaSelecionada = (args['aba'] as int?) ?? 0;
        if (args['termoParada'] != null) {
          _termoParadaController.text = args['termoParada'].toString();
        }
        if (args['linhaFiltro'] != null) {
          _filtroLinhaNoPontoController.text = args['linhaFiltro'].toString();
        }
        final int? codigoParadaAlvo = args['codigoParada'] as int?;
        _buscarParadas(codigoParadaPreferencial: codigoParadaAlvo);
        _buscarLinhas();
      } else {
        _localizarPontosPeloMeuGps();
        _buscarLinhas();
      }
    }
  }

  @override
  void dispose() {
    _timerTempoReal?.cancel();
    _termoParadaController.dispose();
    _filtroLinhaNoPontoController.dispose();
    _termoLinhaController.dispose();
    super.dispose();
  }

  void _iniciarTimerTempoReal() {
    _timerTempoReal?.cancel();
    _timerTempoReal = Timer.periodic(_intervaloAtualizacao, (_) {
      if (!mounted || !_atualizacaoAutomatica) return;
      _executarRefreshSilencioso();
    });
  }

  Future<void> _executarRefreshSilencioso() async {
    if (_atualizandoSilenciosamente) return;
    if (_abaSelecionada == 0 && _paradaSelecionada != null) {
      setState(() => _atualizandoSilenciosamente = true);
      try {
        final prev = await ApiService.instance
            .buscarPrevisoesPorParada(_paradaSelecionada!.codigoParada);
        if (!mounted) return;
        setState(() {
          _previsaoParada = prev;
          _ultimaAtualizacao = DateTime.now();
          _atualizandoSilenciosamente = false;
        });
      } catch (_) {
        if (mounted) setState(() => _atualizandoSilenciosamente = false);
      }
    } else if (_abaSelecionada == 1 && _codigoLinhaAvulso != null) {
      setState(() => _atualizandoSilenciosamente = true);
      try {
        final pos = await ApiService.instance
            .buscarVeiculosPorLinha(_codigoLinhaAvulso!);
        if (!mounted) return;
        setState(() {
          _posicaoAtual = pos;
          _ultimaAtualizacao = DateTime.now();
          _atualizandoSilenciosamente = false;
        });
      } catch (_) {
        if (mounted) setState(() => _atualizandoSilenciosamente = false);
      }
    }
  }

  String _formatarHoraAtualizacao() {
    if (_ultimaAtualizacao == null) return '--:--:--';
    final h = _ultimaAtualizacao!.hour.toString().padLeft(2, '0');
    final m = _ultimaAtualizacao!.minute.toString().padLeft(2, '0');
    final s = _ultimaAtualizacao!.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ===========================================================================
  // LÓGICA DA ABA 0: ESTOU NO PONTO DE ÔNIBUS (GPS AUTOMÁTICO + MAPA + PREVISÃO)
  // ===========================================================================

  Future<void> _localizarPontosPeloMeuGps({bool forcarRefreshGps = false}) async {
    setState(() {
      _isLoadingParadas = true;
      _errorMessage = null;
      _paradaSelecionada = null;
      _previsaoParada = null;
    });

    try {
      final gps = await LocationService.instance.obterLocalizacaoAtual(
        forcarAtualizacao: forcarRefreshGps,
      );
      final respGps = await ApiService.instance.buscarParadasProximasPorGps(
        lat: gps.latitude,
        lon: gps.longitude,
        ignorarCache: forcarRefreshGps,
      );
      if (!mounted) return;

      final termoDetectado = respGps.localAtual?.termoBuscaSptrans ?? 'PAULISTA';
      setState(() {
        _posicaoGps = gps;
        _mensagemGpsPonto = respGps.mensagemProximidade;
        _usuarioEstaNoPonto = respGps.usuarioEstaNoPonto;
        _paradas = respGps.paradasProximas;
        _termoParadaController.text = termoDetectado;
        _isLoadingParadas = false;
      });

      final alvo = respGps.paradaMaisProxima ??
          (respGps.paradasProximas.isNotEmpty ? respGps.paradasProximas.first : null);
      if (alvo != null) {
        _selecionarParadaEBuscarPrevisao(alvo);
      }
    } catch (_) {
      if (!mounted) return;
      await _buscarParadas();
    }
  }

  Future<void> _buscarParadas({int? codigoParadaPreferencial}) async {
    final termo = _termoParadaController.text.trim().isEmpty
        ? 'PAULISTA'
        : _termoParadaController.text.trim();

    setState(() {
      _isLoadingParadas = true;
      _errorMessage = null;
      _paradaSelecionada = null;
      _previsaoParada = null;
    });

    try {
      final resultado = await ApiService.instance.buscarParadas(termo);
      if (!mounted) return;
      setState(() {
        _paradas = resultado;
        _isLoadingParadas = false;
      });
      if (resultado.isNotEmpty) {
        ParadaResumoModel alvo = resultado.first;
        if (codigoParadaPreferencial != null) {
          final match = resultado.where((p) => p.codigoParada == codigoParadaPreferencial);
          if (match.isNotEmpty) {
            alvo = match.first;
          }
        }
        _selecionarParadaEBuscarPrevisao(alvo);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingParadas = false;
      });
    }
  }

  Future<void> _selecionarParadaEBuscarPrevisao(ParadaResumoModel parada) async {
    setState(() {
      _paradaSelecionada = parada;
      _isLoadingPrevisao = true;
      _errorMessage = null;
    });

    try {
      final prev = await ApiService.instance.buscarPrevisoesPorParada(parada.codigoParada);
      if (!mounted) return;
      setState(() {
        _previsaoParada = prev;
        _ultimaAtualizacao = DateTime.now();
        _isLoadingPrevisao = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPrevisao = false;
      });
    }
  }

  // ===========================================================================
  // LÓGICA DA ABA 1: ACOMPANHAR FROTA E PARADAS DA LINHA NO MAPA
  // ===========================================================================

  Future<void> _buscarLinhas({int? selecionarCodigoAutomatico}) async {
    final termo = _termoLinhaController.text.trim().isEmpty
        ? '8000'
        : _termoLinhaController.text.trim();

    setState(() {
      _isLoadingLinhas = true;
      _errorMessage = null;
      _ultimoTermoLinha = termo;
      if (selecionarCodigoAutomatico == null) {
        _linhaSelecionada = null;
        _codigoLinhaAvulso = null;
        _posicaoAtual = null;
        _paradasDaLinha = [];
        _paradaDaLinhaSelecionada = null;
      }
    });

    try {
      final resultado = await ApiService.instance.buscarLinhas(termo);
      if (!mounted) return;
      setState(() {
        _linhas = resultado;
        _isLoadingLinhas = false;
      });

      if (selecionarCodigoAutomatico != null) {
        final match = resultado.where((l) => l.codigoLinha == selecionarCodigoAutomatico);
        if (match.isNotEmpty) {
          _selecionarLinhaEBuscarOnibus(match.first);
        } else {
          _carregarVeiculosEParadasPorCodigo(selecionarCodigoAutomatico, termoHint: termo);
        }
      } else if (resultado.isNotEmpty) {
        _selecionarLinhaEBuscarOnibus(resultado.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLinhas = false;
      });
    }
  }

  Future<void> _selecionarLinhaEBuscarOnibus(LinhaResumoModel linha) async {
    setState(() {
      _linhaSelecionada = linha;
      _codigoLinhaAvulso = linha.codigoLinha;
      _isLoadingVeiculos = true;
      _errorMessage = null;
    });

    final termoHint = linha.terminalPrincipal.isNotEmpty
        ? linha.terminalPrincipal
        : _ultimoTermoLinha;
    await _carregarVeiculosEParadasPorCodigo(linha.codigoLinha, termoHint: termoHint);
  }

  Future<void> _carregarVeiculosEParadasPorCodigo(
    int codigoLinha, {
    String? termoHint,
  }) async {
    setState(() {
      _codigoLinhaAvulso = codigoLinha;
      _isLoadingVeiculos = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.instance.buscarVeiculosPorLinha(codigoLinha),
        ApiService.instance.buscarParadasPorLinha(codigoLinha, termo: termoHint),
      ]);
      if (!mounted) return;
      final pos = results[0] as PosicaoLinhaResponseModel;
      final paradasApi = results[1] as List<ParadaResumoModel>;
      final paradasLinha =
          await ParadasLinhaFallbackHelper.garantirParadasDaLinha(
        paradasIniciais: paradasApi,
        veiculos: pos.veiculos,
        descricaoSentido: _linhaSelecionada?.descricaoSentido ?? termoHint,
        letreiroCompleto:
            _linhaSelecionada?.letreiroCompleto ?? '$codigoLinha',
      );
      if (!mounted) return;
      setState(() {
        _posicaoAtual = pos;
        _paradasDaLinha = paradasLinha;
        _paradaDaLinhaSelecionada =
            paradasLinha.isNotEmpty ? paradasLinha.first : null;
        _ultimaAtualizacao = DateTime.now();
        _isLoadingVeiculos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingVeiculos = false;
      });
    }
  }

  // ===========================================================================
  // CONVERSÃO DOS DADOS PARA PINOS DO MAPA
  // ===========================================================================

  List<MapaVeiculoPin> _gerarPinosVeiculosNoPonto() {
    final todasLinhasNoPonto = _previsaoParada?.parada?.linhas ?? [];
    final filtroLinha = _filtroLinhaNoPontoController.text.trim().toUpperCase();
    final linhasFiltradas = filtroLinha.isEmpty
        ? todasLinhasNoPonto
        : todasLinhasNoPonto.where((lp) {
            return lp.letreiroCompleto.toUpperCase().contains(filtroLinha) ||
                lp.destino.toUpperCase().contains(filtroLinha) ||
                lp.origem.toUpperCase().contains(filtroLinha);
          }).toList();

    final List<MapaVeiculoPin> pinos = [];
    for (final lp in (linhasFiltradas.isNotEmpty ? linhasFiltradas : todasLinhasNoPonto)) {
      for (final v in lp.veiculos) {
        if (v.possuiCoordenadas) {
          pinos.add(
            MapaVeiculoPin(
              prefixo: v.prefixo,
              letreiro: lp.letreiroCompleto,
              acessivelPcD: v.acessivelPcD,
              horarioChegada: v.horarioPrevistoChegada,
              latitude: v.latitude,
              longitude: v.longitude,
            ),
          );
        }
      }
    }
    return pinos;
  }

  List<MapaVeiculoPin> _gerarPinosFrotaLinha() {
    final veiculos = _posicaoAtual?.veiculos ?? [];
    final letreiroAtual = _linhaSelecionada?.letreiroCompleto ??
        (_codigoLinhaAvulso != null ? '$_codigoLinhaAvulso' : '');
    return veiculos
        .map(
          (v) => MapaVeiculoPin(
            prefixo: v.prefixo,
            letreiro: letreiroAtual,
            acessivelPcD: v.acessivelPcD,
            horarioChegada: v.horarioCaptura.isNotEmpty ? 'GPS ${v.horarioCaptura}' : null,
            latitude: v.latitude,
            longitude: v.longitude,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Radar SPTrans'),
        actions: [
          const ThemeSelectorButton(),
          IconButton(
            tooltip: _modoMapaExpandido
                ? 'Alternar para Modo Clássico (Lista)'
                : 'Alternar para Modo Mapa',
            onPressed: () =>
                setState(() => _modoMapaExpandido = !_modoMapaExpandido),
            icon: Icon(
              _modoMapaExpandido
                  ? Icons.view_agenda_outlined
                  : Icons.map_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Como Chegar',
            onPressed: () => Navigator.pushNamed(context, '/route-planner'),
            icon: const Icon(Icons.route),
          ),
        ],
      ),
      body: _modoMapaExpandido ? _buildModoMoovit() : _buildModoClassico(),
    );
  }

  // ===========================================================================
  // MODO MOOVIT: MAPA EM DESTAQUE + BARRA DE BUSCA + DRAGGABLE BOTTOM SHEET
  // ===========================================================================

  Widget _buildModoMoovit() {
    final todasLinhasNoPonto = _previsaoParada?.parada?.linhas ?? [];
    final filtroLinha = _filtroLinhaNoPontoController.text.trim().toUpperCase();
    final bool? linhaConfirmadaNoPonto = filtroLinha.isEmpty
        ? null
        : todasLinhasNoPonto.any(
            (lp) =>
                lp.letreiroCompleto.toUpperCase().contains(filtroLinha) ||
                lp.destino.toUpperCase().contains(filtroLinha),
          );

    final letreiroAtual = _linhaSelecionada?.letreiroCompleto ??
        (_codigoLinhaAvulso != null ? '$_codigoLinhaAvulso' : '');

    return Column(
      children: [
        // Barra superior compacta (Modo + Busca + Ao Vivo 15s)
        _buildTopMoovitBar(),

        // Mapa em Tela Ampla + Painel Deslizante (DraggableScrollableSheet)
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _abaSelecionada == 0
                    ? PontoMapWidget(
                        expandido: true,
                        paradas: _paradas,
                        paradaSelecionada: _paradaSelecionada,
                        onSelecionarParada: _selecionarParadaEBuscarPrevisao,
                        veiculos: _gerarPinosVeiculosNoPonto(),
                        tituloMapa: 'Estou no Ponto',
                        linhaDestacada:
                            filtroLinha.isEmpty ? null : filtroLinha,
                        linhaPassaNestePonto: linhaConfirmadaNoPonto,
                        usuarioLat: _posicaoGps?.latitude,
                        usuarioLon: _posicaoGps?.longitude,
                      )
                    : PontoMapWidget(
                        expandido: true,
                        paradas: _paradasDaLinha,
                        paradasTrajetoLinha: _paradasDaLinha,
                        paradaSelecionada: _paradaDaLinhaSelecionada,
                        onSelecionarParada: (p) {
                          setState(() => _paradaDaLinhaSelecionada = p);
                        },
                        veiculos: _gerarPinosFrotaLinha(),
                        tituloMapa: letreiroAtual.isNotEmpty
                            ? 'Linha $letreiroAtual'
                            : 'Buscar por Linha',
                        linhaDestacada:
                            letreiroAtual.isNotEmpty ? letreiroAtual : null,
                        usuarioLat: _posicaoGps?.latitude,
                        usuarioLon: _posicaoGps?.longitude,
                      ),
              ),

              // Painel Eletrônico Deslizante Estilo Moovit
              DraggableScrollableSheet(
                initialChildSize: 0.30,
                minChildSize: 0.14,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.16, 0.30, 0.65, 0.85],
                builder: (context, scrollController) {
                  final colors = Theme.of(context).colorScheme;
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      children: [
                        // Alça visual do BottomSheet
                        Center(
                          child: Container(
                            width: 42,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: colors.outlineVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: colors.onErrorContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (_abaSelecionada == 0)
                          ..._buildConteudoAbaPonto(incluirMapaCard: false)
                        else
                          ..._buildConteudoAbaLinha(incluirMapaCard: false),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopMoovitBar() {
    final colors = Theme.of(context).colorScheme;
    final liveColor = AppTheme.adaptiveSuccess(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          // Seletor compacto de Aba + Chip Ao Vivo 15s
          Row(
            children: [
              Expanded(
                child: _CompactModePill(
                  selected: _abaSelecionada == 0,
                  icon: Icons.place,
                  label: '1. No Ponto',
                  onTap: () => setState(() => _abaSelecionada = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactModePill(
                  selected: _abaSelecionada == 1,
                  icon: Icons.directions_bus,
                  label: '2. Por Linha',
                  onTap: () => setState(() => _abaSelecionada = 1),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _atualizacaoAutomatica = !_atualizacaoAutomatica;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _atualizacaoAutomatica
                        ? AppTheme.badgeBgSuccess(context)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _atualizacaoAutomatica
                          ? liveColor
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_atualizandoSilenciosamente)
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: liveColor,
                          ),
                        )
                      else
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _atualizacaoAutomatica
                              ? liveColor
                              : colors.onSurfaceVariant,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        _atualizacaoAutomatica ? '15s' : 'Pausado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _atualizacaoAutomatica
                              ? liveColor
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Barra de busca rápida contextual
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _abaSelecionada == 0
                      ? _termoParadaController
                      : _termoLinhaController,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  onSubmitted: (_) =>
                      _abaSelecionada == 0 ? _buscarParadas() : _buscarLinhas(),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    hintText: _abaSelecionada == 0
                        ? 'Buscar avenida/ponto (Paulista, Lapa...)'
                        : 'Buscar linha (8000, 875A, Paulista...)',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                    prefixIcon: Icon(
                      _abaSelecionada == 0
                          ? Icons.place_outlined
                          : Icons.directions_bus_outlined,
                      color: colors.primary,
                      size: 18,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_abaSelecionada == 0)
                IconButton(
                  tooltip: 'Usar meu GPS atual',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  onPressed: _isLoadingParadas
                      ? null
                      : () => _localizarPontosPeloMeuGps(forcarRefreshGps: true),
                  icon: const Icon(Icons.my_location, size: 19),
                ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  minimumSize: Size.zero,
                ),
                onPressed: () =>
                    _abaSelecionada == 0 ? _buscarParadas() : _buscarLinhas(),
                child: const Icon(Icons.search, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODO CLÁSSICO: LISTVIEW COM CARTÕES + MAPA EMBUTIDO
  // ===========================================================================

  Widget _buildModoClassico() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Guia Didático para o Cidadão
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.badgeBgInfo(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.map_outlined, color: colors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Como saber se você está no Ponto Correto?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Veja no mapa abaixo a posição exata da parada e o lado da avenida (B/C ou C/B). '
                'Digite o número do seu ônibus para confirmar se ele passa neste ponto e acompanhar o trajeto da linha.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Seletor de Modo (Aba 0 vs Aba 1)
        Row(
          children: [
            Expanded(
              child: _ModeTabButton(
                selected: _abaSelecionada == 0,
                icon: Icons.place,
                title: '1. Estou no Ponto',
                subtitle: 'Mapa do ponto + Previsão',
                onTap: () => setState(() => _abaSelecionada = 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeTabButton(
                selected: _abaSelecionada == 1,
                icon: Icons.directions_bus,
                title: '2. Buscar por Linha',
                subtitle: 'Frota, trajeto e paradas',
                onTap: () => setState(() => _abaSelecionada = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null)
          Card(
            color: colors.errorContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        if (_abaSelecionada == 0)
          ..._buildConteudoAbaPonto(incluirMapaCard: true)
        else
          ..._buildConteudoAbaLinha(incluirMapaCard: true),
      ],
    );
  }

  // ===========================================================================
  // CONTEÚDO COMPARTILHADO DA ABA 0: ESTOU NO PONTO
  // ===========================================================================

  List<Widget> _buildConteudoAbaPonto({required bool incluirMapaCard}) {
    final colors = Theme.of(context).colorScheme;
    final todasLinhasNoPonto = _previsaoParada?.parada?.linhas ?? [];
    final filtroLinha = _filtroLinhaNoPontoController.text.trim().toUpperCase();

    final linhasFiltradas = filtroLinha.isEmpty
        ? todasLinhasNoPonto
        : todasLinhasNoPonto.where((lp) {
            return lp.letreiroCompleto.toUpperCase().contains(filtroLinha) ||
                lp.destino.toUpperCase().contains(filtroLinha) ||
                lp.origem.toUpperCase().contains(filtroLinha);
          }).toList();

    final bool? linhaConfirmadaNoPonto = filtroLinha.isEmpty
        ? null
        : todasLinhasNoPonto.any(
            (lp) =>
                lp.letreiroCompleto.toUpperCase().contains(filtroLinha) ||
                lp.destino.toUpperCase().contains(filtroLinha),
          );

    final pinosVeiculosNoPonto = _gerarPinosVeiculosNoPonto();

    return [
      if (incluirMapaCard) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '1º Passo: Sua localização ou avenida do ponto',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isLoadingParadas
                          ? null
                          : () => _localizarPontosPeloMeuGps(forcarRefreshGps: true),
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Usar Meu GPS'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _termoParadaController,
                        onSubmitted: (_) => _buscarParadas(),
                        decoration: const InputDecoration(
                          hintText: 'Ex.: Paulista, Lapa, Pinheiros, Consolação...',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoadingParadas ? null : () => _buscarParadas(),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],

      // Mensagem de GPS + Sugestões rápidas de avenida
      if (_mensagemGpsPonto != null && _mensagemGpsPonto!.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _usuarioEstaNoPonto == true
                ? AppTheme.badgeBgSuccess(context)
                : AppTheme.badgeBgInfo(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _usuarioEstaNoPonto == true
                  ? AppTheme.adaptiveSuccess(context).withValues(alpha: 0.45)
                  : colors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _usuarioEstaNoPonto == true
                    ? Icons.check_circle
                    : Icons.directions_walk,
                size: 18,
                color: _usuarioEstaNoPonto == true
                    ? AppTheme.adaptiveSuccess(context)
                    : colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _mensagemGpsPonto!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),

      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Paulista', 'Lapa', 'Pinheiros', 'Consolação', 'Santo Amaro']
              .map((sugestao) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(sugestao, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _termoParadaController.text = sugestao;
                        _buscarParadas();
                      },
                    ),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 10),

      if (_isLoadingParadas)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_paradas.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: Text('Nenhum ponto de ônibus encontrado para este termo.'),
            ),
          ),
        )
      else ...[
        Text(
          'Pontos próximos (${_paradas.length}) — toque para comparar B/C e C/B:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _paradas.take(12).length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final p = _paradas[index];
              final isSelected = _paradaSelecionada?.codigoParada == p.codigoParada;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selecionarParadaEBuscarPrevisao(p),
                child: Container(
                  width: 245,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.badgeBgInfo(context)
                        : AppTheme.softSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.person_pin_circle : Icons.place,
                            size: 17,
                            color: isSelected ? colors.primary : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.nomeParada.isEmpty ? 'Parada ${p.codigoParada}' : p.nomeParada,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary.withValues(alpha: 0.14)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.ladoDaViaExplicado,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? colors.primary : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.endereco.isEmpty ? 'Código SPTrans: ${p.codigoParada}' : p.endereco,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        if (incluirMapaCard) ...[
          PontoMapWidget(
            paradas: _paradas,
            paradaSelecionada: _paradaSelecionada,
            onSelecionarParada: _selecionarParadaEBuscarPrevisao,
            veiculos: pinosVeiculosNoPonto,
            tituloMapa: 'Mapa do Ponto: Confira o lado da via',
            linhaDestacada: filtroLinha.isEmpty ? null : filtroLinha,
            linhaPassaNestePonto: linhaConfirmadaNoPonto,
            usuarioLat: _posicaoGps?.latitude,
            usuarioLon: _posicaoGps?.longitude,
          ),
          const SizedBox(height: 14),
        ],

        // Filtro de linha no ponto
        TextField(
          controller: _filtroLinhaNoPontoController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Filtrar linha neste ponto (ex.: 875A, 8000, Lapa...)',
            prefixIcon: const Icon(Icons.directions_bus_outlined),
            suffixIcon: _filtroLinhaNoPontoController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Mostrar todas as linhas do ponto',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _filtroLinhaNoPontoController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
        ),
        if (todasLinhasNoPonto.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Passam aqui: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.adaptiveSuccess(context),
                  ),
                ),
                ...todasLinhasNoPonto.take(8).map((lp) {
                  final isSelectedChip =
                      filtroLinha == lp.letreiroCompleto.toUpperCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: isSelectedChip
                          ? colors.secondary.withValues(alpha: 0.24)
                          : AppTheme.badgeBgSuccess(context),
                      label: Text(
                        lp.letreiroCompleto,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.adaptiveSuccess(context),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isSelectedChip) {
                            _filtroLinhaNoPontoController.clear();
                          } else {
                            _filtroLinhaNoPontoController.text = lp.letreiroCompleto;
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Painel Eletrônico de Previsão de Chegada na Parada Selecionada
        if (_paradaSelecionada != null)
          _buildPainelEletronicoParada(
            todasLinhasNoPonto: todasLinhasNoPonto,
            linhasFiltradas: linhasFiltradas,
            filtroLinha: filtroLinha,
          ),
      ],
    ];
  }

  Widget _buildPainelEletronicoParada({
    required List<LinhaPrevisaoModel> todasLinhasNoPonto,
    required List<LinhaPrevisaoModel> linhasFiltradas,
    required String filtroLinha,
  }) {
    final colors = Theme.of(context).colorScheme;
    final successColor = AppTheme.adaptiveSuccess(context);
    final warningColor = AppTheme.adaptiveWarning(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Painel Eletrônico: ${_paradaSelecionada!.nomeParada}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        '${_paradaSelecionada!.endereco} • ${_paradaSelecionada!.ladoDaViaExplicado}'
                        '${_ultimaAtualizacao != null ? " • Ref. ${_formatarHoraAtualizacao()}" : ""}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar previsões de chegada',
                  onPressed: () =>
                      _selecionarParadaEBuscarPrevisao(_paradaSelecionada!),
                  icon: Icon(Icons.refresh, color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingPrevisao)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (todasLinhasNoPonto.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Nenhum ônibus com previsão imediata neste minuto para este ponto. '
                  'Toque em outro pino no mapa para checar o outro lado da avenida.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else if (linhasFiltradas.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.badgeBgWarning(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: warningColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A linha "$filtroLinha" não aparece nas previsões deste ponto (${_paradaSelecionada!.nomeParada}).',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: warningColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você pode estar no ponto do sentido oposto da rua. Toque em outro ponto no mapa ou limpe o filtro.',
                      style: TextStyle(fontSize: 12, color: colors.onSurface),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Ônibus se aproximando (${linhasFiltradas.length} linhas):',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: successColor,
                ),
              ),
              const SizedBox(height: 8),
              ...linhasFiltradas.map((lp) {
                final proximoVeiculo =
                    lp.veiculos.isNotEmpty ? lp.veiculos.first : null;
                double? distanciaMetros;
                if (proximoVeiculo != null &&
                    proximoVeiculo.possuiCoordenadas &&
                    _paradaSelecionada!.possuiCoordenadas) {
                  distanciaMetros = PontoMapWidget.calcularDistanciaMetros(
                    _paradaSelecionada!.latitude,
                    _paradaSelecionada!.longitude,
                    proximoVeiculo.latitude,
                    proximoVeiculo.longitude,
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.softSurface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lp.letreiroCompleto,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Destino: ${lp.destino}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                            if (proximoVeiculo != null)
                              Row(
                                children: [
                                  if (proximoVeiculo.acessivelPcD) ...[
                                    Icon(
                                      Icons.accessible,
                                      size: 13,
                                      color: colors.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '${proximoVeiculo.acessivelPcD ? "Com Elevador PcD" : "Sem Elevador PcD"}'
                                      '${distanciaMetros != null ? " • ${PontoMapWidget.formatarDistancia(distanciaMetros)}" : ""}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: proximoVeiculo.acessivelPcD
                                            ? colors.secondary
                                            : warningColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (proximoVeiculo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeBgSuccess(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: successColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'CHEGA ÀS',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: successColor,
                                ),
                              ),
                              Text(
                                proximoVeiculo.horarioPrevistoChegada,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CONTEÚDO COMPARTILHADO DA ABA 1: BUSCAR POR LINHA
  // ===========================================================================

  List<Widget> _buildConteudoAbaLinha({required bool incluirMapaCard}) {
    final colors = Theme.of(context).colorScheme;
    final successColor = AppTheme.adaptiveSuccess(context);
    final warningColor = AppTheme.adaptiveWarning(context);
    final veiculos = _posicaoAtual?.veiculos ?? [];
    final totalAcessiveis = veiculos.where((v) => v.acessivelPcD).length;
    final letreiroAtual = _linhaSelecionada?.letreiroCompleto ?? '$_codigoLinhaAvulso';
    final pinosFrotaLinha = _gerarPinosFrotaLinha();

    return [
      if (incluirMapaCard) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qual linha de ônibus você quer ver no mapa ou fiscalizar?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Digite o número do letreiro (ex.: 875A, 8000) ou bairro (ex.: Paulista, Lapa) para ver o trajeto completo e os ônibus.',
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _termoLinhaController,
                        onSubmitted: (_) => _buscarLinhas(),
                        decoration: InputDecoration(
                          hintText: 'Ex.: 8000, 875A ou Paulista',
                          prefixIcon: const Icon(Icons.directions_bus),
                          suffixIcon: _termoLinhaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _termoLinhaController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoadingLinhas ? null : () => _buscarLinhas(),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],

      Text(
        'Sentidos para "$_ultimoTermoLinha" (${_linhas.length}):',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: colors.onSurface,
        ),
      ),
      const SizedBox(height: 8),

      if (_isLoadingLinhas)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_linhas.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: Text('Nenhuma linha encontrada com esse nome ou número.'),
            ),
          ),
        )
      else
        ..._linhas.map((linha) {
          final isSelected = _linhaSelecionada?.codigoLinha == linha.codigoLinha;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected
                ? AppTheme.badgeBgInfo(context)
                : AppTheme.softSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _selecionarLinhaEBuscarOnibus(linha),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            color: isSelected ? colors.onPrimary : colors.onSurface,
                            size: 16,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            linha.letreiroCompleto,
                            style: TextStyle(
                              color: isSelected ? colors.onPrimary : colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isSelected) ...[
                                Icon(Icons.check_circle, size: 12, color: colors.primary),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  isSelected
                                      ? 'EXIBINDO TRAJETO E FROTA DESTE SENTIDO'
                                      : 'SENTIDO ${linha.sentido == 1 ? "IDA" : "VOLTA"}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            linha.descricaoSentido,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radar : Icons.chevron_right,
                      color: isSelected ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

      const SizedBox(height: 12),

      if (_linhaSelecionada != null || _codigoLinhaAvulso != null) ...[
        if (incluirMapaCard &&
            (pinosFrotaLinha.isNotEmpty || _paradasDaLinha.isNotEmpty)) ...[
          PontoMapWidget(
            paradas: _paradasDaLinha,
            paradasTrajetoLinha: _paradasDaLinha,
            paradaSelecionada: _paradaDaLinhaSelecionada,
            onSelecionarParada: (p) {
              setState(() => _paradaDaLinhaSelecionada = p);
            },
            veiculos: pinosFrotaLinha,
            tituloMapa: 'Linha $letreiroAtual',
            linhaDestacada: letreiroAtual,
            usuarioLat: _posicaoGps?.latitude,
            usuarioLon: _posicaoGps?.longitude,
          ),
          const SizedBox(height: 14),
        ],

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.secondary, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.gps_fixed,
                        color: colors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _linhaSelecionada != null
                                ? 'Ônibus na rua — Linha ${_linhaSelecionada!.letreiroCompleto}'
                                : 'Ônibus na rua — Linha $_codigoLinhaAvulso',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          if (_linhaSelecionada != null)
                            Text(
                              '${_linhaSelecionada!.descricaoSentido}'
                              '${_ultimaAtualizacao != null ? " • Ref. ${_formatarHoraAtualizacao()}" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar frota',
                      icon: Icon(Icons.refresh, color: colors.secondary),
                      onPressed: () {
                        if (_codigoLinhaAvulso != null) {
                          _carregarVeiculosEParadasPorCodigo(
                            _codigoLinhaAvulso!,
                            termoHint: _linhaSelecionada?.terminalPrincipal,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingVeiculos && _posicaoAtual == null)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_posicaoAtual != null) ...[
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.badgeBgSuccess(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.accessible_forward,
                          color: successColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            veiculos.isEmpty
                                ? 'Nenhum ônibus desta linha está com GPS transmitindo neste minuto.'
                                : 'Há ${veiculos.length} ônibus circulando agora '
                                    '($totalAcessiveis com elevador PcD). '
                                    'Identifique pelo prefixo na porta:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...veiculos.map((v) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppTheme.softSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: v.acessivelPcD
                              ? colors.secondary.withValues(alpha: 0.5)
                              : warningColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: v.acessivelPcD
                                ? AppTheme.secondaryTeal
                                : AppTheme.accentAmber,
                            child: Icon(
                              v.acessivelPcD
                                  ? Icons.accessible
                                  : Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ônibus nº ${v.prefixo}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                  ),
                                ),
                                Text(
                                  v.acessivelPcD
                                      ? 'Com Elevador PcD'
                                      : 'Sem Elevador PcD',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: v.acessivelPcD
                                        ? colors.secondary
                                        : warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/occurrence-form',
                                arguments: {
                                  'codigoLinha': _linhaSelecionada?.codigoLinha ??
                                      _codigoLinhaAvulso,
                                  'letreiro': _linhaSelecionada?.letreiroCompleto,
                                  'prefixoVeiculo': v.prefixo,
                                },
                              );
                            },
                            icon: const Icon(Icons.report_problem_outlined, size: 16),
                            label: const Text('Relatar'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

class _CompactModePill extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompactModePill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? colors.onPrimary : colors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? colors.onPrimary.withValues(alpha: 0.78)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
