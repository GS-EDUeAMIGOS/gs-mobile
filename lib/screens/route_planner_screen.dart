import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/ponto_map_widget.dart';
import '../widgets/theme_selector_button.dart';

/// Camada: Screens (Tela 7 — Planejador de Viagem "Como Chegar" com GPS Automático e Busca por Locais)
/// Responsabilidade Única:
/// 1. Capturar automaticamente por padrão a localização GPS do celular do cidadão como ponto de partida
///    (permitindo que ele altere manualmente depois se quiser).
/// 2. Permitir buscar destinos pelo nome de locais reais (ex.: "Hospital Heliópolis", "Hospital das Clínicas",
///    "Shopping Ibirapuera", "USP") via geocodificação no backend.
/// 3. Exibir o passo a passo completo: caminhar até o ponto X ➔ pegar ônibus Y ➔ fazer baldeação em Z ➔ caminhar até o destino.
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _origemController = TextEditingController(text: 'Minha Localização Atual (GPS)');
  final _destinoController = TextEditingController(text: 'Hospital Heliópolis');

  PosicaoUsuarioGps? _posicaoGps;
  bool _usandoGpsNaOrigem = true;

  RotaPlanejadaResponseModel? _rotaPlanejada;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initializedArgs = false;

  // Locais reais e destinos de São Paulo para seleção rápida
  static const List<Map<String, dynamic>> _destinosPopulares = [
    {
      'nome': 'Hospital Heliópolis',
      'termo': 'Hospital Heliópolis',
      'subtitulo': 'Sacomã — R. Cônego Xavier',
      'icone': Icons.local_hospital,
    },
    {
      'nome': 'Hospital das Clínicas',
      'termo': 'Hospital das Clínicas',
      'subtitulo': 'Cerqueira César — Paulista',
      'icone': Icons.medical_services,
    },
    {
      'nome': 'Av. Paulista / MASP',
      'termo': 'Av. Paulista',
      'subtitulo': 'Bela Vista — Metrô Trianon',
      'icone': Icons.business,
    },
    {
      'nome': 'Parque Ibirapuera',
      'termo': 'Parque Ibirapuera',
      'subtitulo': 'Moema / Vila Mariana',
      'icone': Icons.park,
    },
    {
      'nome': 'Pinheiros / Faria Lima',
      'termo': 'Pinheiros',
      'subtitulo': 'Zona Oeste — Terminal',
      'icone': Icons.location_city,
    },
    {
      'nome': 'Terminal Lapa',
      'termo': 'Terminal Lapa',
      'subtitulo': 'Zona Oeste — Integração',
      'icone': Icons.directions_transit,
    },
    {
      'nome': 'Santo Amaro',
      'termo': 'Santo Amaro',
      'subtitulo': 'Zona Sul — Largo Treze',
      'icone': Icons.transfer_within_a_station,
    },
  ];

  static const String _chipMeuGps = 'Meu GPS';

  static const List<String> _origensRapidas = [
    _chipMeuGps,
    'Paulista',
    'Lapa',
    'Pinheiros',
    'Vila Mariana',
    'Santo Amaro',
    'Santana',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['origem'] != null) {
          _origemController.text = args['origem'].toString();
          _usandoGpsNaOrigem = false;
        }
        if (args['destino'] != null) {
          _destinoController.text = args['destino'].toString();
        }
      }
      _inicializarGpsECalcularRota();
    }
  }

  @override
  void dispose() {
    _origemController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  Future<void> _inicializarGpsECalcularRota() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pos = await LocationService.instance.obterLocalizacaoAtual();
      if (!mounted) return;
      setState(() {
        _posicaoGps = pos;
      });
    } catch (_) {
      // Segue normalmente caso o GPS não responda
    }

    await _calcularRota();
  }

  Future<void> _ativarMeuGpsNaOrigem() async {
    setState(() {
      _isLoading = true;
      _usandoGpsNaOrigem = true;
      _origemController.text = 'Minha Localização Atual (GPS)';
    });

    final pos = await LocationService.instance.obterLocalizacaoAtual(
      forcarAtualizacao: true,
    );
    if (!mounted) return;
    setState(() {
      _posicaoGps = pos;
    });
    await _calcularRota();
  }

  void _inverterOrigemDestino() {
    final temp = _origemController.text;
    setState(() {
      _usandoGpsNaOrigem = false;
      _origemController.text = _destinoController.text;
      _destinoController.text =
          temp.contains('GPS') ? 'Av. Paulista' : temp;
    });
    _calcularRota();
  }

  void _selecionarDestinoRapido(String termoDestino) {
    setState(() {
      _destinoController.text = termoDestino;
    });
    _calcularRota();
  }

  Future<void> _calcularRota() async {
    final textoOrigem = _origemController.text.trim();
    final destino = _destinoController.text.trim().isEmpty
        ? 'Hospital Heliópolis'
        : _destinoController.text.trim();

    // Se estiver usando GPS na origem, envia exclusivamente as coordenadas do aparelho para o backend
    // (sem misturar com Paulista!)
    final bool enviarCoordenadasGps = _usandoGpsNaOrigem && _posicaoGps != null;
    final String origemParaApi = enviarCoordenadasGps
        ? 'GPS'
        : (textoOrigem.isEmpty ? 'IPIRANGA' : textoOrigem);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultado = await ApiService.instance.planejarRota(
        origem: origemParaApi,
        destino: destino,
        latOrigem: enviarCoordenadasGps ? _posicaoGps!.latitude : null,
        lonOrigem: enviarCoordenadasGps ? _posicaoGps!.longitude : null,
      );
      if (!mounted) return;

      // Se o usuário digitou manualmente sua rua/bairro de partida, atualiza a posição no LocationService
      if (!enviarCoordenadasGps &&
          resultado.localOrigemResolvido != null &&
          resultado.localOrigemResolvido!.latitude != 0.0) {
        LocationService.instance.definirLocalizacaoManual(
          latitude: resultado.localOrigemResolvido!.latitude,
          longitude: resultado.localOrigemResolvido!.longitude,
          descricao: resultado.localOrigemResolvido!.nomeLocal,
        );
      }

      setState(() {
        _rotaPlanejada = resultado;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = _rotaPlanejada?.opcoes ?? [];
    final localOrig = _rotaPlanejada?.localOrigemResolvido;
    final localDest = _rotaPlanejada?.localDestinoResolvido;

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Como Chegar'),
        actions: [
          const ThemeSelectorButton(),
          IconButton(
            tooltip: 'Recalcular rotas em tempo real',
            icon: const Icon(Icons.refresh),
            onPressed: _calcularRota,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Card Buscador de Origem (com GPS automático por padrão) e Destino (Locais Reais)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: colors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Planejar trajeto',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Campos de Origem (GPS ou digitado) e Destino (Local real)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _origemController,
                              onChanged: (val) {
                                if (_usandoGpsNaOrigem &&
                                    val != 'Minha Localização Atual (GPS)') {
                                  setState(() => _usandoGpsNaOrigem = false);
                                }
                              },
                              onSubmitted: (_) => _calcularRota(),
                              decoration: InputDecoration(
                                labelText: 'Ponto de Partida',
                                hintText: 'Sua localização, rua ou bairro',
                                prefixIcon: Icon(
                                  _usandoGpsNaOrigem
                                      ? Icons.my_location
                                      : Icons.trip_origin,
                                  color: colors.primary,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Usar localização GPS atual do aparelho',
                                  icon: Icon(
                                    Icons.gps_fixed,
                                    color: _usandoGpsNaOrigem
                                        ? colors.secondary
                                        : colors.onSurfaceVariant,
                                  ),
                                  onPressed: _ativarMeuGpsNaOrigem,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _destinoController,
                              onSubmitted: (_) => _calcularRota(),
                              decoration: InputDecoration(
                                labelText: 'Destino',
                                hintText: 'Ex.: Hospital Heliópolis, Clínicas, Ibirapuera',
                                prefixIcon: Icon(
                                  Icons.place,
                                  color: colors.error,
                                ),
                                suffixIcon: _destinoController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _destinoController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Inverter Origem e Destino',
                        onPressed: _inverterOrigemDestino,
                        icon: const Icon(Icons.swap_vert),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Atalhos rápidos de Origem (incluindo Meu GPS)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Partida: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        ..._origensRapidas.map((orig) {
                          final isGpsChip = orig == _chipMeuGps;
                          final isSelected = isGpsChip
                              ? _usandoGpsNaOrigem
                              : (!_usandoGpsNaOrigem &&
                                  _origemController.text.trim().toUpperCase() ==
                                      orig.toUpperCase());
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: isGpsChip
                                  ? Icon(
                                      Icons.my_location,
                                      size: 14,
                                      color: isSelected
                                          ? colors.onPrimaryContainer
                                          : colors.primary,
                                    )
                                  : null,
                              backgroundColor: isSelected
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              label: Text(
                                orig,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                              ),
                              onPressed: () {
                                if (isGpsChip) {
                                  _ativarMeuGpsNaOrigem();
                                } else {
                                  setState(() {
                                    _usandoGpsNaOrigem = false;
                                    _origemController.text = orig;
                                  });
                                  _calcularRota();
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _calcularRota,
                      icon: const Icon(Icons.directions_bus),
                      label: const Text('Traçar Rota'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Destinos frequentes (exibidos antes do cálculo para não empurrar o resultado para baixo)
          if (_rotaPlanejada == null) ...[
            Text(
              'Destinos frequentes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _destinosPopulares.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = _destinosPopulares[index];
                  final termo = item['termo'] as String;
                  final isSelected = _destinoController.text
                          .trim()
                          .toUpperCase() ==
                      termo.toUpperCase();

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _selecionarDestinoRapido(termo),
                    child: Container(
                      width: 205,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primaryContainer
                            : colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item['icone'] as IconData,
                              size: 20,
                              color: isSelected ? colors.onPrimary : colors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['nome'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['subtitulo'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 3. Exibição dos Resultados do Planejador
          if (_isLoading)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      'Calculando rota e consultando linhas disponíveis...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Card(
              color: colors.errorContainer,
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
            )
          else if (_rotaPlanejada != null) ...[
            // Resumo discreto de Origem e Destino resolvidos
            if (localOrig != null || localDest != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.softSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localOrig != null)
                      Row(
                        children: [
                          Icon(Icons.my_location, size: 16, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Partida: ${localOrig.nomeLocal} (${_rotaPlanejada!.distanciaCaminhadaOrigemMetros} m até o ponto)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (localOrig != null && localDest != null)
                      const SizedBox(height: 6),
                    if (localDest != null)
                      Row(
                        children: [
                          Icon(Icons.place, size: 16, color: colors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Destino: ${localDest.nomeLocal}'
                              '${localDest.bairro.isNotEmpty ? " — ${localDest.bairro}" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            if (opcoes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Não encontramos linhas para estes termos. Tente usar o nome do hospital, parque, bairro ou avenida principal.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              // Mapa do Ponto de Embarque Sugerido na Origem (com a localização GPS do usuário)
              Builder(
                builder: (context) {
                  final melhorOpcao = opcoes.first;
                  // Procura o primeiro passo de embarque de ônibus para destacar o ponto e o ônibus
                  PassoRotaModel? passoEmbarque;
                  for (final p in melhorOpcao.passos) {
                    if (p.tipoPasso == 'EMBARQUE_DIRETO' || p.tipoPasso == 'EMBARQUE') {
                      passoEmbarque = p;
                      break;
                    }
                  }
                  passoEmbarque ??=
                      melhorOpcao.passos.isNotEmpty ? melhorOpcao.passos.first : null;

                  final paradaDestaque = (passoEmbarque != null &&
                          passoEmbarque.possuiCoordenadasParada)
                      ? ParadaResumoModel(
                          codigoParada: passoEmbarque.codigoParada ?? 0,
                          nomeParada: passoEmbarque.nomeParada ?? passoEmbarque.local,
                          endereco: passoEmbarque.enderecoParada ?? '',
                          latitude: passoEmbarque.latitudeParada!,
                          longitude: passoEmbarque.longitudeParada!,
                        )
                      : _rotaPlanejada!.paradaOrigemSugerida;

                  final paradasMapa = _rotaPlanejada!.paradasProximasOrigem.isNotEmpty
                      ? _rotaPlanejada!.paradasProximasOrigem
                      : (paradaDestaque != null
                          ? [paradaDestaque]
                          : <ParadaResumoModel>[]);

                  final List<MapaVeiculoPin> veiculosMapa = [];
                  if (passoEmbarque != null &&
                      passoEmbarque.possuiCoordenadasVeiculo &&
                      passoEmbarque.proximoPrefixo != null) {
                    veiculosMapa.add(
                      MapaVeiculoPin(
                        prefixo: passoEmbarque.proximoPrefixo!,
                        letreiro: passoEmbarque.letreiroCompleto,
                        acessivelPcD: passoEmbarque.veiculosAcessiveisPcD > 0,
                        latitude: passoEmbarque.latitudeProximoVeiculo!,
                        longitude: passoEmbarque.longitudeProximoVeiculo!,
                      ),
                    );
                  }

                  if (paradasMapa.isEmpty && veiculosMapa.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PontoMapWidget(
                      paradas: paradasMapa,
                      paradaSelecionada: paradaDestaque,
                      veiculos: veiculosMapa,
                      tituloMapa:
                          'Mapa do Ponto onde você vai pegar o ônibus',
                      linhaDestacada: passoEmbarque?.letreiroCompleto,
                      linhaPassaNestePonto:
                          passoEmbarque?.pontoConfirmadoNaParada == true ? true : null,
                      usuarioLat: _usandoGpsNaOrigem
                          ? _posicaoGps?.latitude
                          : localOrig?.latitude,
                      usuarioLon: _usandoGpsNaOrigem
                          ? _posicaoGps?.longitude
                          : localOrig?.longitude,
                      onSelecionarParada: (p) {
                        Navigator.pushNamed(
                          context,
                          '/sptrans',
                          arguments: {
                            'aba': 0,
                            'termoParada':
                                localOrig?.termoBuscaSptrans ?? _rotaPlanejada!.origemBuscada,
                            'codigoParada': p.codigoParada,
                            'linhaFiltro': passoEmbarque?.letreiroCompleto,
                          },
                        );
                      },
                    ),
                  );
                },
              ),
              ...opcoes.map(
                (opcao) => _RouteOptionCard(
                  opcao: opcao,
                  rotaPlanejada: _rotaPlanejada!,
                  termoOrigem:
                      localOrig?.termoBuscaSptrans ?? _rotaPlanejada!.origemBuscada,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatefulWidget {
  final OpcaoRotaModel opcao;
  final RotaPlanejadaResponseModel rotaPlanejada;
  final String termoOrigem;

  const _RouteOptionCard({
    required this.opcao,
    required this.rotaPlanejada,
    required this.termoOrigem,
  });

  @override
  State<_RouteOptionCard> createState() => _RouteOptionCardState();
}

class _RouteOptionCardState extends State<_RouteOptionCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final opcao = widget.opcao;
    final isDireta = opcao.tipoRota == 'DIRETA';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: opcao.recomendada ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: opcao.recomendada
              ? colors.secondary
              : colors.outlineVariant,
          width: opcao.recomendada ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (opcao.recomendada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryTeal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'RECOMENDADA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDireta
                        ? AppTheme.badgeBgInfo(context)
                        : AppTheme.badgeBgWarning(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDireta
                        ? '1 ÔNIBUS (DIRETO)'
                        : '2 ÔNIBUS (BALDEAÇÃO)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDireta
                          ? colors.primary
                          : AppTheme.adaptiveWarning(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 13, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '~${opcao.tempoEstimadoMinutos} min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (opcao.totalmenteAcessivelPcD)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.badgeBgSuccess(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.accessible,
                          size: 13,
                          color: AppTheme.adaptiveSuccess(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PcD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.adaptiveSuccess(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              opcao.titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              opcao.motivoRecomendacao,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Botão visível e direto para iniciar a rota
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/route-navigation',
                    arguments: {
                      'opcao': opcao,
                      'rota': widget.rotaPlanejada,
                    },
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Iniciar Rota',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: opcao.recomendada
                      ? AppTheme.secondaryTeal
                      : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expandido = !_expandido),
                icon: Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _expandido
                      ? 'Ocultar passo a passo'
                      : 'Ver passo a passo (${opcao.passos.length} etapas)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            if (_expandido) ...[
              const Divider(height: 12),
              const SizedBox(height: 8),
              ...opcao.passos.map(
                (passo) => _StepTimelineItem(
                  passo: passo,
                  termoOrigem: widget.termoOrigem,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepTimelineItem extends StatelessWidget {
  final PassoRotaModel passo;
  final String termoOrigem;

  const _StepTimelineItem({
    required this.passo,
    required this.termoOrigem,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCaminhada = passo.tipoPasso == 'CAMINHADA';
    final isDesembarque = passo.tipoPasso == 'DESEMBARQUE';
    final isBaldeacao = passo.tipoPasso == 'BALDEACAO';

    final Color badgeColor = isCaminhada
        ? colors.primary
        : isDesembarque
            ? colors.secondary
            : isBaldeacao
                ? AppTheme.adaptiveWarning(context)
                : colors.primary;

    final Color stepBgColor = isCaminhada
        ? AppTheme.badgeBgInfo(context)
        : isDesembarque
            ? AppTheme.badgeBgSuccess(context)
            : isBaldeacao
                ? AppTheme.badgeBgWarning(context)
                : AppTheme.softSurface(context);

    final IconData stepIcon = isCaminhada
        ? Icons.directions_walk
        : isDesembarque
            ? Icons.flag_rounded
            : isBaldeacao
                ? Icons.transfer_within_a_station
                : Icons.directions_bus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: badgeColor.withValues(alpha: 0.18),
                child: Icon(stepIcon, size: 18, color: badgeColor),
              ),
              if (!isDesembarque)
                Container(
                  width: 2,
                  height: 60,
                  color: colors.outlineVariant,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stepBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCaminhada ? Icons.directions_walk : Icons.place_outlined,
                        size: 15,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          passo.local,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      if (passo.pontoConfirmadoNaParada)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeBgSuccess(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 12,
                                color: AppTheme.adaptiveSuccess(context),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Ponto Confirmado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.adaptiveSuccess(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    passo.instrucao,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),

                  if (!isDesembarque && !isCaminhada) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Linha ${passo.letreiroCompleto}',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${passo.veiculosAcessiveisPcD} com elevador PcD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                    if (passo.previsaoChegada.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        passo.previsaoChegada,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if ((passo.codigoParada != null && passo.codigoParada! > 0) ||
                        passo.codigoLinha > 0) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (passo.codigoParada != null && passo.codigoParada! > 0)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/sptrans',
                                  arguments: {
                                    'aba': 0,
                                    'termoParada': termoOrigem,
                                    'codigoParada': passo.codigoParada,
                                    'linhaFiltro': passo.letreiroCompleto,
                                  },
                                );
                              },
                              icon: const Icon(Icons.map_outlined, size: 15),
                              label: const Text(
                                'Mapa do Ponto',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (passo.codigoLinha > 0)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/sptrans',
                                  arguments: passo.codigoLinha,
                                );
                              },
                              icon: const Icon(Icons.radar, size: 15),
                              label: const Text(
                                'Ver Linha',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],

                  if (passo.alertaComunidade != null &&
                      passo.alertaComunidade!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: colors.onErrorContainer,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              passo.alertaComunidade!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
