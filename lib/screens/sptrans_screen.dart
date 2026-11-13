import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ponto_map_widget.dart';

/// Camada: Screens (Tela 6 — Radar SPTrans Olho Vivo em Tempo Real com Mapa do Ponto)
/// Responsabilidade Única: Oferecer ao cidadão um painel em tempo real e um Mapa Interativo
/// para ter certeza absoluta de que está no ponto de ônibus correto (e do lado certo da avenida)
/// onde passa o seu ônibus, além de fiscalizar a frota acessível PcD.
class SptransScreen extends StatefulWidget {
  const SptransScreen({super.key});

  @override
  State<SptransScreen> createState() => _SptransScreenState();
}

class _SptransScreenState extends State<SptransScreen> {
  // 0 = Estou no Ponto (Mapa do Ponto + Previsão de Chegada + Verificador de Linha)
  // 1 = Buscar por Linha (Mapa da Frota na Rua + Pontos da Linha)
  int _abaSelecionada = 0;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        // Quando vem de uma ocorrência ou do Planejador para ver uma linha específica
        _abaSelecionada = 1;
        _codigoLinhaAvulso = args;
        _buscarLinhas(selecionarCodigoAutomatico: args);
        _buscarParadas();
      } else if (args is Map<String, dynamic>) {
        // Quando vem do Planejador de Rotas para conferir o Ponto de Embarque no Mapa
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
        // Por padrão, captura automaticamente a localização GPS do aparelho para achar o ponto mais próximo
        _localizarPontosPeloMeuGps();
        _buscarLinhas();
      }
    }
  }

  @override
  void dispose() {
    _termoParadaController.dispose();
    _filtroLinhaNoPontoController.dispose();
    _termoLinhaController.dispose();
    super.dispose();
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
    } catch (e) {
      if (!mounted) return;
      // Fallback caso o endpoint /paradas/proximas oscile: busca pelo termo atual
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
      final paradasLinha = results[1] as List<ParadaResumoModel>;
      setState(() {
        _posicaoAtual = pos;
        _paradasDaLinha = paradasLinha;
        _paradaDaLinhaSelecionada =
            paradasLinha.isNotEmpty ? paradasLinha.first : null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar & Mapa de Pontos (SPTrans)'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/route-planner'),
            icon: const Icon(Icons.route, color: Colors.white, size: 18),
            label: const Text(
              'Como Chegar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Guia Didático para o Cidadão: Como saber se estou no ponto certo?
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.08),
                  AppTheme.secondaryTeal.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.secondaryTeal.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppTheme.primaryBlue, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Como saber se você está no Ponto Correto?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Veja no Mapa Interativo abaixo a posição exata da parada e de qual lado da avenida ela fica (Sentido Bairro➔Centro "B/C" ou Centro➔Bairro "C/B").\n'
                  '• Digite o número do seu ônibus para o sistema confirmar se ele passa exatamente neste ponto e mostrar a quantos metros ele está!',
                  style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Seletor de Modo (Aba 0: Estou no Ponto vs Aba 1: Buscar por Linha)
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
                  subtitle: 'Mapa da frota e paradas',
                  onTap: () => setState(() => _abaSelecionada = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null)
            Card(
              color: const Color(0xFFFEF2F2),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.dangerRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // 3. Conteúdo Dinâmico conforme a Aba escolhida pelo Cidadão
          if (_abaSelecionada == 0)
            _buildAbaEstouNoPonto()
          else
            _buildAbaBuscarPorLinha(),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI DA ABA 0: ESTOU NO PONTO (MAPA DO PONTO + VERIFICADOR DE LINHA + PAINEL)
  // ===========================================================================
  Widget _buildAbaEstouNoPonto() {
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

    // Converte os veículos que estão chegando neste ponto para pinos no mapa
    final List<MapaVeiculoPin> pinosVeiculosNoPonto = [];
    for (final lp in (linhasFiltradas.isNotEmpty ? linhasFiltradas : todasLinhasNoPonto)) {
      for (final v in lp.veiculos) {
        if (v.possuiCoordenadas) {
          pinosVeiculosNoPonto.add(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card de Busca da Avenida/Ponto + Filtro "Qual ônibus você quer pegar?"
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        '1º Passo: Sua localização ou avenida do ponto',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
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
                if (_mensagemGpsPonto != null && _mensagemGpsPonto!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _usuarioEstaNoPonto == true
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _usuarioEstaNoPonto == true
                            ? const Color(0xFF22C55E)
                            : AppTheme.primaryBlue.withValues(alpha: 0.35),
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
                              ? const Color(0xFF15803D)
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _mensagemGpsPonto!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _usuarioEstaNoPonto == true
                                  ? const Color(0xFF14532D)
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      label: const Text('Buscar Ponto'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['PAULISTA', 'LAPA', 'PINHEIROS', 'CONSOLACAO', 'SANTO AMARO']
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
                const Divider(height: 24),
                const Text(
                  '2º Passo (Opcional): Qual ônibus você está esperando?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Digite o número da linha (ex.: 875A-10, 8000, 917M) para o mapa confirmar se ela passa neste ponto!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _filtroLinhaNoPontoController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
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
                        const Text(
                          'Passam aqui agora: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        ...todasLinhasNoPonto.take(8).map((lp) {
                          final isSelectedChip =
                              filtroLinha == lp.letreiroCompleto.toUpperCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              backgroundColor: isSelectedChip
                                  ? AppTheme.secondaryTeal.withValues(alpha: 0.2)
                                  : const Color(0xFFF0FDF4),
                              label: Text(
                                lp.letreiroCompleto,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF14532D),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoadingParadas)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_paradas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Nenhum ponto de ônibus encontrado para este termo.'),
              ),
            ),
          )
        else ...[
          // Carrossel de Pontos Encontrados com indicação clara do lado da via (B/C vs C/B)
          Text(
            'Pontos encontrados na via (${_paradas.length}) — escolha o seu ponto:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
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
                    width: 255,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
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
                              size: 18,
                              color: isSelected ? AppTheme.primaryBlue : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p.nomeParada.isEmpty ? 'Parada #${p.codigoParada}' : p.nomeParada,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
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
                                ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.ladoDaViaExplicado,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppTheme.primaryBlue : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.endereco.isEmpty ? 'Código SPTrans: ${p.codigoParada}' : p.endereco,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // MAPA INTERATIVO DO PONTO E ÔNIBUS PRÓXIMOS
          PontoMapWidget(
            paradas: _paradas,
            paradaSelecionada: _paradaSelecionada,
            onSelecionarParada: _selecionarParadaEBuscarPrevisao,
            veiculos: pinosVeiculosNoPonto,
            tituloMapa: 'Mapa do Ponto: Confira se está do lado certo da via',
            linhaDestacada: filtroLinha.isEmpty ? null : filtroLinha,
            linhaPassaNestePonto: linhaConfirmadaNoPonto,
            usuarioLat: _posicaoGps?.latitude,
            usuarioLon: _posicaoGps?.longitude,
          ),
          const SizedBox(height: 16),

          // Painel Eletrônico de Previsão de Chegada na Parada Selecionada
          if (_paradaSelecionada != null)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: AppTheme.primaryBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Painel Eletrônico: ${_paradaSelecionada!.nomeParada}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${_paradaSelecionada!.endereco} • ${_paradaSelecionada!.ladoDaViaExplicado}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atualizar previsões de chegada',
                          onPressed: () =>
                              _selecionarParadaEBuscarPrevisao(_paradaSelecionada!),
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_isLoadingPrevisao)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (todasLinhasNoPonto.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Nenhum ônibus com previsão imediata neste minuto para este ponto. '
                          'Toque em outro pino no mapa acima para checar o outro lado da avenida!',
                          style: TextStyle(color: Color(0xFF475569)),
                        ),
                      )
                    else if (linhasFiltradas.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ A linha "$filtroLinha" não aparece nas previsões deste ponto (${_paradaSelecionada!.nomeParada}).',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Você pode estar no ponto do sentido oposto da rua! Toque em outro ponto no mapa acima ou limpe o filtro para ver todas as linhas que param aqui.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text(
                        'Ônibus que param neste ponto se aproximando agora (${linhasFiltradas.length} linhas):',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lp.letreiroCompleto,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Destino: ${lp.destino}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (proximoVeiculo != null)
                                      Text(
                                        'Ônibus nº ${proximoVeiculo.prefixo} • '
                                        '${proximoVeiculo.acessivelPcD ? "♿ Com Elevador PcD" : "Sem Elevador PcD"}'
                                        '${distanciaMetros != null ? " • ${PontoMapWidget.formatarDistancia(distanciaMetros)}" : ""}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: proximoVeiculo.acessivelPcD
                                              ? AppTheme.secondaryTeal
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (proximoVeiculo != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.secondaryTeal.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'CHEGA ÀS',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      Text(
                                        proximoVeiculo.horarioPrevistoChegada,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF14532D),
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
            ),
        ],
      ],
    );
  }

  // ===========================================================================
  // UI DA ABA 1: BUSCAR POR LINHA (MAPA DA FROTA E PONTOS DA LINHA)
  // ===========================================================================
  Widget _buildAbaBuscarPorLinha() {
    final veiculos = _posicaoAtual?.veiculos ?? [];
    final totalAcessiveis = veiculos.where((v) => v.acessivelPcD).length;
    final letreiroAtual = _linhaSelecionada?.letreiroCompleto ?? '#$_codigoLinhaAvulso';

    final List<MapaVeiculoPin> pinosFrotaLinha = veiculos
        .map(
          (v) => MapaVeiculoPin(
            prefixo: v.prefixo,
            letreiro: letreiroAtual,
            acessivelPcD: v.acessivelPcD,
            latitude: v.latitude,
            longitude: v.longitude,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Qual linha de ônibus você quer ver no mapa ou fiscalizar?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Digite o número do letreiro (ex.: 875A, 8000) ou o bairro (ex.: Paulista, Lapa) para ver onde os ônibus e paradas estão no mapa.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
        const SizedBox(height: 14),

        Text(
          'Sentidos encontrados para "$_ultimoTermoLinha" (${_linhas.length}):',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoadingLinhas)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_linhas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Nenhuma linha encontrada com esse nome ou número.'),
              ),
            ),
          )
        else
          ..._linhas.map((linha) {
            final isSelected = _linhaSelecionada?.codigoLinha == linha.codigoLinha;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selecionarLinhaEBuscarOnibus(linha),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryBlue : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.directions_bus, color: Colors.white, size: 18),
                            const SizedBox(height: 2),
                            Text(
                              linha.letreiroCompleto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSelected
                                  ? '✓ EXIBINDO MAPA E FROTA DESTE SENTIDO'
                                  : 'SENTIDO ${linha.sentido == 1 ? "IDA" : "VOLTA"}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppTheme.primaryBlue
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              linha.descricaoSentido,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.radar : Icons.chevron_right,
                        color: isSelected ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        if (_linhaSelecionada != null || _codigoLinhaAvulso != null) ...[
          // Mapa mostrando os ônibus em tempo real desta linha e os pontos de parada
          if (!_isLoadingVeiculos && (pinosFrotaLinha.isNotEmpty || _paradasDaLinha.isNotEmpty)) ...[
            PontoMapWidget(
              paradas: _paradasDaLinha,
              paradaSelecionada: _paradaDaLinhaSelecionada,
              onSelecionarParada: (p) {
                setState(() => _paradaDaLinhaSelecionada = p);
              },
              veiculos: pinosFrotaLinha,
              tituloMapa: 'Mapa ao Vivo • Linha $letreiroAtual e Pontos de Parada',
            ),
            const SizedBox(height: 16),
          ],

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.secondaryTeal, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.gps_fixed,
                          color: AppTheme.secondaryTeal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _linhaSelecionada != null
                                  ? 'Ônibus na rua agora • Linha ${_linhaSelecionada!.letreiroCompleto}'
                                  : 'Ônibus na rua agora (Código #$_codigoLinhaAvulso)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (_linhaSelecionada != null)
                              Text(
                                _linhaSelecionada!.descricaoSentido,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryTeal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Atualizar frota',
                        icon: const Icon(Icons.refresh, color: AppTheme.secondaryTeal),
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
                  const SizedBox(height: 14),

                  if (_isLoadingVeiculos)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_posicaoAtual != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.accessible_forward,
                            color: AppTheme.secondaryTeal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              veiculos.isEmpty
                                  ? 'Nenhum ônibus desta linha está com GPS transmitindo neste minuto.'
                                  : 'Há ${veiculos.length} ônibus circulando agora '
                                    '($totalAcessiveis com elevador PcD). '
                                    'Identifique seu ônibus pelo número pintado na porta:',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF14532D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...veiculos.map((v) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v.acessivelPcD
                                ? AppTheme.secondaryTeal.withValues(alpha: 0.5)
                                : AppTheme.accentAmber.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: v.acessivelPcD
                                  ? AppTheme.secondaryTeal
                                  : AppTheme.accentAmber,
                              child: Icon(
                                v.acessivelPcD
                                    ? Icons.accessible
                                    : Icons.warning_amber_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ônibus nº ${v.prefixo}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    v.acessivelPcD
                                        ? 'Com Elevador PcD'
                                        : 'Sem Elevador PcD',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: v.acessivelPcD
                                          ? AppTheme.secondaryTeal
                                          : const Color(0xFFB45309),
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
      ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.primaryBlue,
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
                      color: selected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white70 : const Color(0xFF64748B),
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
