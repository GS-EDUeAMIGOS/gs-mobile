import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/olho_vivo_model.dart';
import '../theme/map_theme.dart';
import 'map/bus_marker_widget.dart';
import 'map/stop_marker_widget.dart';
import 'map/user_gps_marker_widget.dart';

export 'map/bus_marker_widget.dart' show MapaVeiculoPin;

/// Camada: Widgets (Componente Visual Reutilizável — Mapa Interativo Dark Transit UI)
/// Responsabilidade Única: Renderizar o mapa vetorial/raster interativo (via `flutter_map` +
/// CartoDB Dark Matter / fallback OSM escuro) com:
/// 1. Paradas da SPTrans com clustering em zoom afastado e destaque B/C vs C/B.
/// 2. Terminais e Estações em roxo (#A855F7) com visibilidade prioritária.
/// 3. Polyline Ciano Neon dupla para o trajeto completo da linha e vetor tracejado de aproximação.
/// 4. Ônibus em tempo real com interpolação suave de coordenadas e diferenciação PcD (#10B981) vs comum (#F59E0B).
/// 5. Filtros de camada, controles de navegação e alternador de tema escuro/claro.
class PontoMapWidget extends StatefulWidget {
  final List<ParadaResumoModel> paradas;
  final ParadaResumoModel? paradaSelecionada;
  final ValueChanged<ParadaResumoModel>? onSelecionarParada;
  final List<MapaVeiculoPin> veiculos;
  final String tituloMapa;
  final String? linhaDestacada;
  final bool? linhaPassaNestePonto;
  final double? usuarioLat;
  final double? usuarioLon;

  /// Lista ordenada de paradas da linha selecionada para desenhar a Polyline do trajeto.
  final List<ParadaResumoModel>? paradasTrajetoLinha;

  /// Quando true, o mapa ocupa a altura disponível (ou altura ampliada) estilo Moovit.
  final bool expandido;

  /// Altura do container do mapa no modo card (padrão 360px).
  final double alturaMapa;

  /// Quando true, oculta filtros, legenda longa e badges técnicos para navegação guiada limpa.
  final bool modoNavegacaoSimples;

  const PontoMapWidget({
    super.key,
    required this.paradas,
    this.paradaSelecionada,
    this.onSelecionarParada,
    this.veiculos = const [],
    this.tituloMapa = 'Mapa do Ponto e Ônibus Próximos',
    this.linhaDestacada,
    this.linhaPassaNestePonto,
    this.usuarioLat,
    this.usuarioLon,
    this.paradasTrajetoLinha,
    this.expandido = false,
    this.alturaMapa = 360.0,
    this.modoNavegacaoSimples = false,
  });

  /// Calcula a distância real em metros entre duas coordenadas GPS usando a Fórmula de Haversine.
  static double calcularDistanciaMetros(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double raioTerraMetros = 6371000.0;
    final double dLat = _grausParaRadianos(lat2 - lat1);
    final double dLon = _grausParaRadianos(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_grausParaRadianos(lat1)) *
            math.cos(_grausParaRadianos(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return raioTerraMetros * c;
  }

  static String formatarDistancia(double metros) {
    if (metros < 1000) {
      return '${metros.round()} m do ponto';
    }
    return '${(metros / 1000).toStringAsFixed(1)} km do ponto';
  }

  /// Converte horários ISO (ex.: `2026-11-15T20:22:16Z`) ou `HH:mm:ss` em texto amigável.
  static String formatarHorarioAmigavel(String? horarioRaw) {
    if (horarioRaw == null) return '';
    var limpo = horarioRaw.trim();
    if (limpo.isEmpty) return '';

    if (limpo.toUpperCase().startsWith('GPS ')) {
      limpo = limpo.substring(4).trim();
    }

    final parsedIso = DateTime.tryParse(limpo);
    if (parsedIso != null) {
      final local = parsedIso.toLocal();
      final diffSeg = DateTime.now().difference(local).inSeconds.abs();
      if (diffSeg < 60) {
        return 'Agora mesmo';
      }
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return 'Atualizado às $hh:$mm';
    }

    final matchHora = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(limpo);
    if (matchHora != null) {
      final hh = matchHora.group(1)!.padLeft(2, '0');
      final mm = matchHora.group(2)!;
      return 'Atualizado às $hh:$mm';
    }

    return limpo;
  }

  static double _grausParaRadianos(double graus) => graus * (math.pi / 180.0);

  @override
  State<PontoMapWidget> createState() => _PontoMapWidgetState();
}

class _PontoMapWidgetState extends State<PontoMapWidget>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Estado da câmera e tema do mapa
  double _currentZoom = MapTheme.defaultZoom;
  late LatLng _initialCenter;
  bool _mapReady = false;
  bool _isDarkTheme = true;
  // O CartoDB passou a exigir chave de API paga nos seus basemaps.
  // Usamos o OpenStreetMap gratuito com o filtro de matriz escura de alto contraste nativo como padrão.
  bool _useOsmFallback = true;
  int _cartoErrorCount = 0;

  // Filtros interativos de camada
  bool _showPontos = true;
  bool _showTerminais = true;
  bool _showOnibus = true;
  bool _onlyPcdBuses = false;
  bool _showTrajeto = true;

  // Veículo tocado no mapa para exibição rápida no rodapé interno
  MapaVeiculoPin? _veiculoEmDestaque;

  // Interpolação suave das coordenadas dos ônibus (~1000ms)
  late final AnimationController _busAnimController;
  late final Animation<double> _busAnimCurve;
  final Map<String, LatLng> _fromBusPositions = {};
  final Map<String, LatLng> _toBusPositions = {};

  @override
  void initState() {
    super.initState();
    _initialCenter = _calcularCentroInicial();
    _busAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _busAnimCurve = CurvedAnimation(
      parent: _busAnimController,
      curve: Curves.easeInOutCubic,
    );
    _sincronizarPosicoesVeiculos(widget.veiculos, animar: false);
  }

  @override
  void didUpdateWidget(covariant PontoMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Atualiza posições dos veículos com interpolação suave SEM resetar zoom/centro do usuário
    if (!_mesmaListaVeiculos(oldWidget.veiculos, widget.veiculos)) {
      _sincronizarPosicoesVeiculos(widget.veiculos, animar: true);
      if (_veiculoEmDestaque != null) {
        final atualizado = widget.veiculos.where(
          (v) => v.prefixo == _veiculoEmDestaque!.prefixo,
        );
        _veiculoEmDestaque = atualizado.isNotEmpty ? atualizado.first : null;
      }
    }

    // 2. Move a câmera apenas se a parada selecionada mudou ou uma nova busca de paradas/trajeto foi feita
    final mudouParadaSelecionada = widget.paradaSelecionada?.codigoParada !=
        oldWidget.paradaSelecionada?.codigoParada;
    final mudouConjuntoParadas =
        !_mesmasParadas(oldWidget.paradas, widget.paradas);
    final mudouTrajeto = !_mesmasParadas(
      oldWidget.paradasTrajetoLinha ?? const [],
      widget.paradasTrajetoLinha ?? const [],
    );

    if (mudouParadaSelecionada &&
        widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      _moverCameraSePronto(
        LatLng(
          widget.paradaSelecionada!.latitude,
          widget.paradaSelecionada!.longitude,
        ),
        math.max(_currentZoom, MapTheme.defaultZoom),
      );
    } else if (mudouTrajeto &&
        (widget.paradasTrajetoLinha?.where((p) => p.possuiCoordenadas).length ??
                0) >=
            2) {
      _enquadrarRotaEOnibus();
    } else if (mudouConjuntoParadas && widget.paradas.isNotEmpty) {
      final centro = _calcularCentroInicial();
      _moverCameraSePronto(centro, _currentZoom);
    }
  }

  @override
  void dispose() {
    _busAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _busKey(MapaVeiculoPin v) => '${v.prefixo}_${v.letreiro}';

  bool _mesmaListaVeiculos(
    List<MapaVeiculoPin> a,
    List<MapaVeiculoPin> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].prefixo != b[i].prefixo ||
          a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  bool _mesmasParadas(
    List<ParadaResumoModel> a,
    List<ParadaResumoModel> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return a.first.codigoParada == b.first.codigoParada &&
        a.last.codigoParada == b.last.codigoParada;
  }

  LatLng _obterPosicaoInterpolada(MapaVeiculoPin v) {
    final key = _busKey(v);
    final from = _fromBusPositions[key];
    final to = _toBusPositions[key];
    if (from == null || to == null) {
      return LatLng(v.latitude, v.longitude);
    }
    final t = _busAnimCurve.value;
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  void _sincronizarPosicoesVeiculos(
    List<MapaVeiculoPin> novosVeiculos, {
    required bool animar,
  }) {
    final Map<String, LatLng> novosFrom = {};
    final Map<String, LatLng> novosTo = {};
    bool houveDeslocamento = false;

    for (final v in novosVeiculos) {
      if (!v.possuiCoordenadas) continue;
      final key = _busKey(v);
      final destino = LatLng(v.latitude, v.longitude);
      final posicaoAtual = _obterPosicaoInterpolada(v);

      final hadPrevious = _toBusPositions.containsKey(key);
      if (hadPrevious) {
        novosFrom[key] = posicaoAtual;
        if ((posicaoAtual.latitude - destino.latitude).abs() > 1e-6 ||
            (posicaoAtual.longitude - destino.longitude).abs() > 1e-6) {
          houveDeslocamento = true;
        }
      } else {
        novosFrom[key] = destino;
      }
      novosTo[key] = destino;
    }

    _fromBusPositions
      ..clear()
      ..addAll(novosFrom);
    _toBusPositions
      ..clear()
      ..addAll(novosTo);

    if (animar && houveDeslocamento) {
      _busAnimController.forward(from: 0.0);
    }
  }

  LatLng _calcularCentroInicial() {
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      return LatLng(
        widget.paradaSelecionada!.latitude,
        widget.paradaSelecionada!.longitude,
      );
    }
    final paradasValidas =
        widget.paradas.where((p) => p.possuiCoordenadas).toList();
    if (paradasValidas.isNotEmpty) {
      return LatLng(
        paradasValidas.first.latitude,
        paradasValidas.first.longitude,
      );
    }
    final trajetoValido = (widget.paradasTrajetoLinha ?? const [])
        .where((p) => p.possuiCoordenadas)
        .toList();
    if (trajetoValido.isNotEmpty) {
      return LatLng(
        trajetoValido.first.latitude,
        trajetoValido.first.longitude,
      );
    }
    final veiculosValidos =
        widget.veiculos.where((v) => v.possuiCoordenadas).toList();
    if (veiculosValidos.isNotEmpty) {
      return LatLng(
        veiculosValidos.first.latitude,
        veiculosValidos.first.longitude,
      );
    }
    if (widget.usuarioLat != null && widget.usuarioLon != null) {
      return LatLng(widget.usuarioLat!, widget.usuarioLon!);
    }
    return MapTheme.defaultCenter;
  }

  void _moverCameraSePronto(LatLng centro, double zoom) {
    final z = zoom.clamp(MapTheme.minZoom, MapTheme.maxZoom);
    if (_mapReady) {
      _mapController.move(centro, z);
    }
    if (mounted) {
      setState(() => _currentZoom = z);
    }
  }

  void _centralizarNoUsuarioOuPonto() {
    if (widget.usuarioLat != null &&
        widget.usuarioLon != null &&
        widget.usuarioLat != 0.0 &&
        widget.usuarioLon != 0.0) {
      _moverCameraSePronto(
        LatLng(widget.usuarioLat!, widget.usuarioLon!),
        16.2,
      );
      return;
    }
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      _moverCameraSePronto(
        LatLng(
          widget.paradaSelecionada!.latitude,
          widget.paradaSelecionada!.longitude,
        ),
        16.2,
      );
      return;
    }
    _moverCameraSePronto(_calcularCentroInicial(), MapTheme.defaultZoom);
  }

  void _enquadrarRotaEOnibus() {
    final List<LatLng> pontos = [];
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      pontos.add(LatLng(
        widget.paradaSelecionada!.latitude,
        widget.paradaSelecionada!.longitude,
      ));
    }
    for (final p in widget.paradasTrajetoLinha ?? const <ParadaResumoModel>[]) {
      if (p.possuiCoordenadas) {
        pontos.add(LatLng(p.latitude, p.longitude));
      }
    }
    for (final v in widget.veiculos) {
      if (v.possuiCoordenadas) {
        pontos.add(LatLng(v.latitude, v.longitude));
      }
    }
    if (pontos.isEmpty) {
      for (final p in widget.paradas) {
        if (p.possuiCoordenadas) {
          pontos.add(LatLng(p.latitude, p.longitude));
        }
      }
    }

    if (pontos.length >= 2 && _mapReady) {
      final bounds = LatLngBounds.fromPoints(pontos);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(42),
          maxZoom: 16.5,
          minZoom: MapTheme.minZoom,
        ),
      );
      if (mounted) {
        setState(() => _currentZoom = _mapController.camera.zoom);
      }
    } else {
      _centralizarNoUsuarioOuPonto();
    }
  }

  List<ParadaResumoModel> _combinarParadasVisiveis() {
    final Map<int, ParadaResumoModel> porCodigo = {};
    for (final p in widget.paradas) {
      if (p.possuiCoordenadas) porCodigo[p.codigoParada] = p;
    }
    for (final p in widget.paradasTrajetoLinha ?? const <ParadaResumoModel>[]) {
      if (p.possuiCoordenadas) porCodigo.putIfAbsent(p.codigoParada, () => p);
    }
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      porCodigo[widget.paradaSelecionada!.codigoParada] =
          widget.paradaSelecionada!;
    }

    return porCodigo.values.where((p) {
      final isSel = widget.paradaSelecionada?.codigoParada == p.codigoParada;
      if (isSel) return _showPontos || _showTerminais;
      final isTerm = MapTheme.isTerminalOuEstacao(p);
      return isTerm ? _showTerminais : _showPontos;
    }).toList();
  }

  List<MapaVeiculoPin> _filtrarVeiculosVisiveis() {
    if (!_showOnibus) return const [];
    return widget.veiculos.where((v) {
      if (!v.possuiCoordenadas) return false;
      if (_onlyPcdBuses && !v.acessivelPcD) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final paradaAtual = widget.paradaSelecionada;
    final paradasVisiveis = _combinarParadasVisiveis();
    final veiculosVisiveis = _filtrarVeiculosVisiveis();
    final veiculosTodosComGps =
        widget.veiculos.where((v) => v.possuiCoordenadas).toList();

    // Pontos da polyline da linha
    final List<LatLng> pontosTrajeto = _showTrajeto
        ? (widget.paradasTrajetoLinha ?? const <ParadaResumoModel>[])
            .where((p) => p.possuiCoordenadas)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList()
        : const [];

    // Calcula a distância do ônibus mais próximo até a parada selecionada
    double? menorDistanciaMetros;
    MapaVeiculoPin? onibusMaisProximo;
    if (paradaAtual != null && paradaAtual.possuiCoordenadas) {
      for (final v in veiculosVisiveis) {
        final d = PontoMapWidget.calcularDistanciaMetros(
          paradaAtual.latitude,
          paradaAtual.longitude,
          v.latitude,
          v.longitude,
        );
        if (menorDistanciaMetros == null || d < menorDistanciaMetros) {
          menorDistanciaMetros = d;
          onibusMaisProximo = v;
        }
      }
    }

    // Calcula a distância entre o GPS do celular do usuário e o ponto selecionado
    double? distanciaUsuarioAtePonto;
    if (widget.usuarioLat != null &&
        widget.usuarioLon != null &&
        paradaAtual != null &&
        paradaAtual.possuiCoordenadas) {
      final d = PontoMapWidget.calcularDistanciaMetros(
        widget.usuarioLat!,
        widget.usuarioLon!,
        paradaAtual.latitude,
        paradaAtual.longitude,
      );
      if (d < 20000) {
        distanciaUsuarioAtePonto = d;
      }
    }

    final bool mostrarRotulosDetalhados = widget.modoNavegacaoSimples
        ? _currentZoom >= 16.0
        : _currentZoom >= MapTheme.detailedZoomThreshold;
    final bool agruparEmClusters =
        _currentZoom <= MapTheme.clusterZoomThreshold &&
            paradasVisiveis.length > 4;

    final List<StopClusterGroup> clusters = agruparEmClusters
        ? StopClusterHelper.agruparParadas(
            paradas: paradasVisiveis,
            zoom: _currentZoom,
            codigoParadaSelecionada: paradaAtual?.codigoParada,
          )
        : const [];

    final List<Marker> stopMarkers = _construirMarcadoresDeParada(
      paradasVisiveis: paradasVisiveis,
      paradaAtual: paradaAtual,
      agruparEmClusters: agruparEmClusters,
      clusters: clusters,
      mostrarRotulosDetalhados: mostrarRotulosDetalhados,
    );

    return Card(
      elevation: widget.expandido ? 0 : 4,
      margin: widget.expandido ? EdgeInsets.zero : const EdgeInsets.all(4),
      color: MapTheme.surfaceDark,
      shape: widget.expandido
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MapTheme.borderDark, width: 1.2),
            ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: widget.expandido ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho Dark Transit UI
          _buildHeader(paradaAtual, veiculosTodosComGps),

          // 2. Faixa de Distância do GPS do Celular até o Ponto Selecionado
          if (!widget.modoNavegacaoSimples && distanciaUsuarioAtePonto != null)
            _buildDistanciaUsuarioBanner(distanciaUsuarioAtePonto, paradaAtual),

          // 2b. Faixa de Verificação: "Estou no ponto certo para o meu ônibus?"
          if (!widget.modoNavegacaoSimples &&
              widget.linhaDestacada != null &&
              widget.linhaDestacada!.isNotEmpty &&
              widget.linhaPassaNestePonto != null)
            _buildVerificacaoLinhaBanner(paradaAtual),

          // 3. Barra de Filtros de Camada no Mapa (oculta no modo simples)
          if (!widget.modoNavegacaoSimples) _buildFiltrosCamada(),

          // 4. Área Interativa do Mapa (FlutterMap + CartoDB Dark Matter / OSM Fallback)
          _buildMapAreaWrapper(
            context: context,
            pontosTrajeto: pontosTrajeto,
            paradaAtual: paradaAtual,
            stopMarkers: stopMarkers,
            totalParadasVisiveis: paradasVisiveis.length,
            veiculosVisiveis: veiculosVisiveis,
            menorDistanciaMetros: menorDistanciaMetros,
            onibusMaisProximo: onibusMaisProximo,
          ),

          // 5. Rodapé Dark Transit Explicativo (Legenda + Guia B/C vs C/B)
          if (!widget.expandido && !widget.modoNavegacaoSimples)
            _buildFooterLegenda(paradaAtual),
        ],
      ),
    );
  }

  List<Marker> _construirMarcadoresDeParada({
    required List<ParadaResumoModel> paradasVisiveis,
    required ParadaResumoModel? paradaAtual,
    required bool agruparEmClusters,
    required List<StopClusterGroup> clusters,
    required bool mostrarRotulosDetalhados,
  }) {
    final List<Marker> markers = [];

    if (agruparEmClusters) {
      for (final group in clusters) {
        if (group.isCluster) {
          markers.add(
            Marker(
              point: group.centro,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              child: StopClusterMarkerWidget(
                quantidade: group.quantidade,
                onTap: () {
                  _moverCameraSePronto(
                    group.centro,
                    StopClusterHelper.proximoZoomAoAbrirCluster(_currentZoom),
                  );
                },
              ),
            ),
          );
        } else {
          final p = group.paradas.first;
          markers.add(
            Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              child: StopMarkerWidget(
                parada: p,
                selecionada: false,
                isTerminal: false,
                mostrarRotulo: false,
                onTap: () => widget.onSelecionarParada?.call(p),
              ),
            ),
          );
        }
      }

      // Terminais/Estações sempre visíveis fora dos clusters
      for (final p in paradasVisiveis) {
        final isSel = paradaAtual?.codigoParada == p.codigoParada;
        if (!isSel && MapTheme.isTerminalOuEstacao(p)) {
          final exibirRotuloTerminal =
              !widget.modoNavegacaoSimples || mostrarRotulosDetalhados;
          markers.add(
            Marker(
              point: LatLng(p.latitude, p.longitude),
              width: exibirRotuloTerminal ? 145 : 30,
              height: exibirRotuloTerminal ? 50 : 30,
              alignment:
                  exibirRotuloTerminal ? Alignment.bottomCenter : Alignment.center,
              child: StopMarkerWidget(
                parada: p,
                selecionada: false,
                isTerminal: true,
                mostrarRotulo: exibirRotuloTerminal,
                onTap: () => widget.onSelecionarParada?.call(p),
              ),
            ),
          );
        }
      }
    } else {
      for (final p in paradasVisiveis) {
        final isSel = paradaAtual?.codigoParada == p.codigoParada;
        if (isSel) continue; // Parada selecionada é adicionada por último (no topo)
        final isTerm = MapTheme.isTerminalOuEstacao(p);
        markers.add(
          Marker(
            point: LatLng(p.latitude, p.longitude),
            width: mostrarRotulosDetalhados ? 140 : (isTerm ? 30 : 20),
            height: mostrarRotulosDetalhados ? 48 : (isTerm ? 30 : 20),
            alignment: Alignment.center,
            child: StopMarkerWidget(
              parada: p,
              selecionada: false,
              isTerminal: isTerm,
              mostrarRotulo: mostrarRotulosDetalhados,
              onTap: () => widget.onSelecionarParada?.call(p),
            ),
          ),
        );
      }
    }

    // Parada selecionada sempre no topo da camada de paradas
    if (paradaAtual != null && paradaAtual.possuiCoordenadas) {
      markers.add(
        Marker(
          point: LatLng(paradaAtual.latitude, paradaAtual.longitude),
          width: 175,
          height: 58,
          alignment: Alignment.bottomCenter,
          child: StopMarkerWidget(
            parada: paradaAtual,
            selecionada: true,
            isTerminal: MapTheme.isTerminalOuEstacao(paradaAtual),
            mostrarRotulo: true,
            onTap: () => widget.onSelecionarParada?.call(paradaAtual),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildHeader(
    ParadaResumoModel? paradaAtual,
    List<MapaVeiculoPin> veiculosTodosComGps,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: MapTheme.surfaceDark,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: MapTheme.polylineCoreNeon.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MapTheme.polylineCoreNeon.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: MapTheme.userGpsCyan,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: widget.modoNavegacaoSimples
                ? Text(
                    paradaAtual?.nomeParada ?? widget.tituloMapa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MapTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tituloMapa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MapTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        paradaAtual != null
                            ? '${paradaAtual.nomeParada} • ${paradaAtual.ladoDaViaExplicado}'
                            : 'Arraste, dê zoom ou toque nos pinos para inspecionar paradas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MapTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
          if (veiculosTodosComGps.isNotEmpty ||
              (widget.paradasTrajetoLinha?.isNotEmpty ?? false))
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: MapTheme.surfaceCardDark,
                foregroundColor: MapTheme.userGpsCyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: MapTheme.borderDark),
                ),
              ),
              onPressed: _enquadrarRotaEOnibus,
              icon: const Icon(Icons.fit_screen_rounded, size: 15),
              label: const Text(
                'Enquadrar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistanciaUsuarioBanner(
    double distanciaUsuarioAtePonto,
    ParadaResumoModel? paradaAtual,
  ) {
    final bool estaNoPonto = distanciaUsuarioAtePonto <= 85;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: estaNoPonto
          ? const Color(0xFF064E3B)
          : const Color(0xFF0C4A6E),
      child: Row(
        children: [
          Icon(
            estaNoPonto ? Icons.my_location : Icons.directions_walk,
            size: 16,
            color: estaNoPonto
                ? MapTheme.busPcdEmerald
                : MapTheme.userGpsCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              estaNoPonto
                  ? 'GPS: Você já está neste ponto! (${distanciaUsuarioAtePonto.round()}m)'
                  : 'GPS: Você está a ${PontoMapWidget.formatarDistancia(distanciaUsuarioAtePonto)} '
                      '(~${math.max(1, (distanciaUsuarioAtePonto / 75).ceil())} min a pé até ${paradaAtual?.nomeParada ?? "o ponto"})',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: MapTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificacaoLinhaBanner(ParadaResumoModel? paradaAtual) {
    final bool passa = widget.linhaPassaNestePonto == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: passa ? const Color(0xFF065F46) : const Color(0xFF78350F),
      child: Row(
        children: [
          Icon(
            passa ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: passa ? const Color(0xFF6EE7B7) : const Color(0xFFFCD34D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              passa
                  ? 'PONTO CONFIRMADO: A linha ${widget.linhaDestacada} passa em ${paradaAtual?.nomeParada ?? "este ponto"}.'
                  : 'ATENÇÃO AO LADO DA VIA: ${widget.linhaDestacada} não tem previsão imediata aqui. Confira outro lado da rua!',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: MapTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosCamada() {
    return Container(
      color: MapTheme.surfaceCardDark,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MapLayerFilterChip(
              label: 'Pontos',
              icon: Icons.place_outlined,
              active: _showPontos,
              activeColor: MapTheme.stopSelectedBlue,
              onTap: () => setState(() => _showPontos = !_showPontos),
            ),
            const SizedBox(width: 6),
            _MapLayerFilterChip(
              label: 'Terminais',
              icon: Icons.directions_transit,
              active: _showTerminais,
              activeColor: MapTheme.terminalPurple,
              onTap: () => setState(() => _showTerminais = !_showTerminais),
            ),
            const SizedBox(width: 6),
            _MapLayerFilterChip(
              label: 'Ônibus',
              icon: Icons.directions_bus,
              active: _showOnibus,
              activeColor: MapTheme.busStandardAmber,
              onTap: () => setState(() => _showOnibus = !_showOnibus),
            ),
            const SizedBox(width: 6),
            _MapLayerFilterChip(
              label: 'Só PcD ♿',
              icon: Icons.accessible,
              active: _onlyPcdBuses,
              activeColor: MapTheme.busPcdEmerald,
              onTap: () => setState(() {
                _onlyPcdBuses = !_onlyPcdBuses;
                if (_onlyPcdBuses) _showOnibus = true;
              }),
            ),
            const SizedBox(width: 6),
            _MapLayerFilterChip(
              label: 'Trajeto/Linha',
              icon: Icons.timeline,
              active: _showTrajeto,
              activeColor: MapTheme.polylineCoreNeon,
              onTap: () => setState(() => _showTrajeto = !_showTrajeto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAreaWrapper({
    required BuildContext context,
    required List<LatLng> pontosTrajeto,
    required ParadaResumoModel? paradaAtual,
    required List<Marker> stopMarkers,
    required int totalParadasVisiveis,
    required List<MapaVeiculoPin> veiculosVisiveis,
    required double? menorDistanciaMetros,
    required MapaVeiculoPin? onibusMaisProximo,
  }) {
    final Widget mapStack = _buildFlutterMapStack(
      context: context,
      pontosTrajeto: pontosTrajeto,
      paradaAtual: paradaAtual,
      stopMarkers: stopMarkers,
      totalParadasVisiveis: totalParadasVisiveis,
      veiculosVisiveis: veiculosVisiveis,
      menorDistanciaMetros: menorDistanciaMetros,
      onibusMaisProximo: onibusMaisProximo,
    );

    if (widget.expandido) {
      return Expanded(child: mapStack);
    }
    return SizedBox(
      height: widget.alturaMapa,
      child: mapStack,
    );
  }

  Widget _buildFlutterMapStack({
    required BuildContext context,
    required List<LatLng> pontosTrajeto,
    required ParadaResumoModel? paradaAtual,
    required List<Marker> stopMarkers,
    required int totalParadasVisiveis,
    required List<MapaVeiculoPin> veiculosVisiveis,
    required double? menorDistanciaMetros,
    required MapaVeiculoPin? onibusMaisProximo,
  }) {
    final bool temGpsUsuario = widget.usuarioLat != null &&
        widget.usuarioLon != null &&
        widget.usuarioLat != 0.0 &&
        widget.usuarioLon != 0.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _currentZoom,
            minZoom: MapTheme.minZoom,
            maxZoom: MapTheme.maxZoom,
            backgroundColor: _isDarkTheme
                ? MapTheme.mapBackground
                : const Color(0xFFE2E8F0),
            onMapReady: () {
              _mapReady = true;
              if (pontosTrajeto.length >= 2) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _enquadrarRotaEOnibus();
                });
              }
            },
            onTap: (_, _) {
              if (_veiculoEmDestaque != null) {
                setState(() => _veiculoEmDestaque = null);
              }
            },
            onPositionChanged: (camera, hasGesture) {
              if ((camera.zoom - _currentZoom).abs() >= 0.25) {
                setState(() => _currentZoom = camera.zoom);
              }
            },
          ),
          children: [
            // Camada 1: Basemap Escuro Limpo (CartoDB Dark Matter) ou Fallback/Claro OSM
            _buildTileLayer(context),

            // Camada 2: Polyline dupla da linha (Borda #083344 7px + Núcleo Ciano Neon #06B6D4 4px)
            if (pontosTrajeto.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: pontosTrajeto,
                    strokeWidth: MapTheme.polylineBorderWidth,
                    color: MapTheme.polylineBorderDark,
                  ),
                  Polyline(
                    points: pontosTrajeto,
                    strokeWidth: MapTheme.polylineCoreWidth,
                    color: MapTheme.polylineCoreNeon,
                  ),
                ],
              ),

            // Camada 3: Vetor tracejado conectando ônibus em aproximação ao ponto selecionado
            if (_showTrajeto &&
                paradaAtual != null &&
                paradaAtual.possuiCoordenadas &&
                veiculosVisiveis.isNotEmpty &&
                (!widget.modoNavegacaoSimples || onibusMaisProximo != null))
              AnimatedBuilder(
                animation: _busAnimCurve,
                builder: (context, _) {
                  final pontoAlvo =
                      LatLng(paradaAtual.latitude, paradaAtual.longitude);
                  final List<MapaVeiculoPin> alvosVetor =
                      widget.modoNavegacaoSimples
                          ? [onibusMaisProximo!]
                          : veiculosVisiveis.take(8).toList();
                  return PolylineLayer(
                    polylines: alvosVetor
                        .map(
                          (v) => Polyline(
                            points: [_obterPosicaoInterpolada(v), pontoAlvo],
                            strokeWidth: 2.3,
                            color: (v.acessivelPcD
                                    ? MapTheme.busPcdEmerald
                                    : MapTheme.userGpsCyan)
                                .withValues(alpha: 0.75),
                            pattern: StrokePattern.dashed(
                              segments: const [8, 6],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),

            // Camada 4: Localização GPS do Usuário (#38BDF8 pulsante)
            if (temGpsUsuario)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.usuarioLat!, widget.usuarioLon!),
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const UserGpsMarkerWidget(),
                  ),
                ],
              ),

            // Camada 5: Paradas, Terminais e Clusters
            MarkerLayer(markers: stopMarkers),

            // Camada 6: Frota de Ônibus em Tempo Real (com interpolação suave)
            if (veiculosVisiveis.isNotEmpty)
              AnimatedBuilder(
                animation: _busAnimCurve,
                builder: (context, _) {
                  return MarkerLayer(
                    markers: veiculosVisiveis.map((v) {
                      final pos = _obterPosicaoInterpolada(v);
                      final bool compacto = widget.modoNavegacaoSimples
                          ? (_currentZoom < 16.0 &&
                              v.prefixo != onibusMaisProximo?.prefixo)
                          : _currentZoom < 14.5;
                      return Marker(
                        point: pos,
                        width: compacto ? 92 : 160,
                        height: 38,
                        alignment: Alignment.bottomCenter,
                        child: BusMarkerWidget(
                          veiculo: v,
                          compacto: compacto,
                          onTap: () {
                            setState(() => _veiculoEmDestaque = v);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),

        // Controles Flutuantes Escuros no canto direito
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _MapDarkControlButton(
                icon: Icons.add,
                tooltip: 'Aproximar (Zoom +)',
                onTap: () {
                  final nextZoom =
                      (_currentZoom + 1.0).clamp(MapTheme.minZoom, MapTheme.maxZoom);
                  final center = _mapReady
                      ? _mapController.camera.center
                      : _initialCenter;
                  _moverCameraSePronto(center, nextZoom);
                },
              ),
              const SizedBox(height: 6),
              _MapDarkControlButton(
                icon: Icons.remove,
                tooltip: 'Afastar (Zoom -)',
                onTap: () {
                  final nextZoom =
                      (_currentZoom - 1.0).clamp(MapTheme.minZoom, MapTheme.maxZoom);
                  final center = _mapReady
                      ? _mapController.camera.center
                      : _initialCenter;
                  _moverCameraSePronto(center, nextZoom);
                },
              ),
              if (!widget.modoNavegacaoSimples) ...[
                const SizedBox(height: 6),
                _MapDarkControlButton(
                  icon: Icons.my_location,
                  tooltip: 'Centralizar no meu GPS / Ponto',
                  onTap: _centralizarNoUsuarioOuPonto,
                ),
              ],
              const SizedBox(height: 6),
              _MapDarkControlButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Enquadrar ônibus e rota',
                onTap: _enquadrarRotaEOnibus,
              ),
              if (!widget.modoNavegacaoSimples) ...[
                const SizedBox(height: 6),
                _MapDarkControlButton(
                  icon: _isDarkTheme
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  tooltip: _isDarkTheme
                      ? 'Alternar para mapa claro (OSM)'
                      : 'Alternar para mapa escuro (Dark Transit)',
                  onTap: () {
                    setState(() {
                      _isDarkTheme = !_isDarkTheme;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        // Badge discreto de Zoom / Modo no canto superior esquerdo
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MapTheme.surfaceDark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MapTheme.borderDark),
            ),
            child: Text(
              agruparBadgeTexto(totalParadasVisiveis, veiculosVisiveis.length),
              style: const TextStyle(
                color: MapTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // Card de inspeção do ônibus selecionado OU Radar de proximidade
        if (_veiculoEmDestaque != null)
          Positioned(
            left: 10,
            right: 60,
            top: widget.expandido ? 44 : null,
            bottom: widget.expandido ? null : 10,
            child: _buildBusInspectorBanner(_veiculoEmDestaque!, paradaAtual),
          )
        else if (!widget.expandido &&
            menorDistanciaMetros != null &&
            onibusMaisProximo != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _buildRadarDistanciaBanner(
              onibusMaisProximo,
              menorDistanciaMetros,
            ),
          ),
      ],
    );
  }

  String agruparBadgeTexto(int totalParadas, int totalOnibus) {
    if (widget.modoNavegacaoSimples) {
      if (totalOnibus == 0) {
        return 'Ao vivo • Sem ônibus na linha';
      }
      return 'Ao vivo • $totalOnibus ônibus na linha';
    }
    final zoomTxt = 'z${_currentZoom.toStringAsFixed(1)}';
    return '$zoomTxt • $totalParadas pts • $totalOnibus ônibus';
  }

  Widget _buildTileLayer(BuildContext context) {
    if (_isDarkTheme && !_useOsmFallback) {
      return TileLayer(
        key: const ValueKey('tile_carto_dark'),
        urlTemplate: MapTheme.cartoDarkUrlTemplate,
        subdomains: MapTheme.cartoSubdomains,
        retinaMode: RetinaMode.isHighDensity(context),
        userAgentPackageName: MapTheme.userAgentPackageName,
        maxNativeZoom: 18,
        errorTileCallback: (tile, error, stackTrace) {
          _cartoErrorCount++;
          // Se múltiplas tiles do CartoDB falharem (bloqueio de rede/proxy), ativa fallback OSM escuro
          if (_cartoErrorCount >= 6 && mounted && !_useOsmFallback) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_useOsmFallback) {
                setState(() => _useOsmFallback = true);
              }
            });
          }
        },
      );
    }

    if (_isDarkTheme && _useOsmFallback) {
      return TileLayer(
        key: const ValueKey('tile_osm_dark_fallback'),
        urlTemplate: MapTheme.osmUrlTemplate,
        userAgentPackageName: MapTheme.userAgentPackageName,
        maxNativeZoom: 19,
        tileBuilder: (context, tileWidget, tile) => ColorFiltered(
          colorFilter: MapTheme.osmDarkColorFilter,
          child: tileWidget,
        ),
        errorTileCallback: (_, _, _) {},
      );
    }

    return TileLayer(
      key: const ValueKey('tile_osm_light'),
      urlTemplate: MapTheme.osmUrlTemplate,
      userAgentPackageName: MapTheme.userAgentPackageName,
      maxNativeZoom: 19,
      errorTileCallback: (_, _, _) {},
    );
  }

  Widget _buildBusInspectorBanner(
    MapaVeiculoPin veiculo,
    ParadaResumoModel? paradaAtual,
  ) {
    String distTxt = '';
    if (paradaAtual != null && paradaAtual.possuiCoordenadas) {
      final d = PontoMapWidget.calcularDistanciaMetros(
        paradaAtual.latitude,
        paradaAtual.longitude,
        veiculo.latitude,
        veiculo.longitude,
      );
      distTxt = ' • ${PontoMapWidget.formatarDistancia(d)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MapTheme.surfaceDark.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: veiculo.acessivelPcD
              ? MapTheme.busPcdEmerald
              : MapTheme.busStandardAmber,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            veiculo.acessivelPcD ? Icons.accessible : Icons.directions_bus,
            color: veiculo.acessivelPcD
                ? MapTheme.busPcdEmerald
                : MapTheme.busStandardAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${veiculo.letreiro.isNotEmpty ? "Linha ${veiculo.letreiro} • " : ""}Ônibus ${veiculo.prefixo}$distTxt',
                  style: const TextStyle(
                    color: MapTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${veiculo.acessivelPcD ? "Com Elevador PcD (Acessível)" : "Sem Elevador PcD"}'
                  '${_sufixoHorarioAmigavel(veiculo.horarioChegada)}',
                  style: TextStyle(
                    color: veiculo.acessivelPcD
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFFFCD34D),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _veiculoEmDestaque = null),
            icon: const Icon(
              Icons.close,
              size: 18,
              color: MapTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarDistanciaBanner(
    MapaVeiculoPin onibusMaisProximo,
    double menorDistanciaMetros,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MapTheme.surfaceDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MapTheme.borderDark),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radar,
            color: onibusMaisProximo.acessivelPcD
                ? MapTheme.busPcdEmerald
                : MapTheme.userGpsCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ônibus nº ${onibusMaisProximo.prefixo} está a '
              '${PontoMapWidget.formatarDistancia(menorDistanciaMetros)}'
              '${_sufixoHorarioAmigavel(onibusMaisProximo.horarioChegada)}',
              style: const TextStyle(
                color: MapTheme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sufixoHorarioAmigavel(String? horarioRaw) {
    final formatado = PontoMapWidget.formatarHorarioAmigavel(horarioRaw);
    return formatado.isNotEmpty ? ' • $formatado' : '';
  }

  Widget _buildFooterLegenda(ParadaResumoModel? paradaAtual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: MapTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _LegendItemDark(
                color: MapTheme.stopSelectedBlue,
                icon: Icons.directions_bus,
                label: 'Ponto Selecionado',
              ),
              _LegendItemDark(
                color: MapTheme.terminalPurple,
                icon: Icons.directions_transit,
                label: 'Terminal / Estação',
              ),
              _LegendItemDark(
                color: MapTheme.busPcdEmerald,
                icon: Icons.accessible,
                label: 'Ônibus PcD',
              ),
              _LegendItemDark(
                color: MapTheme.busStandardAmber,
                icon: Icons.directions_bus_rounded,
                label: 'Ônibus Comum',
              ),
              _LegendItemDark(
                color: MapTheme.polylineCoreNeon,
                icon: Icons.timeline,
                label: 'Trajeto da Linha',
              ),
            ],
          ),
          if (paradaAtual != null) ...[
            const SizedBox(height: 6),
            Text(
              'Lado da via: "${paradaAtual.nomeParada}" (${paradaAtual.ladoDaViaExplicado}) • '
              'B/C = Bairro➔Centro | C/B = Centro➔Bairro.',
              style: const TextStyle(
                fontSize: 10.5,
                color: MapTheme.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapLayerFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _MapLayerFilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.22)
              : MapTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor : MapTheme.borderDark,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? activeColor : MapTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: active ? MapTheme.textPrimary : MapTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDarkControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapDarkControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapTheme.surfaceDark.withValues(alpha: 0.90),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: MapTheme.borderDark),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: MapTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _LegendItemDark extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _LegendItemDark({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: MapTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
