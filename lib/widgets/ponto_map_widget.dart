import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/olho_vivo_model.dart';
import '../theme/app_theme.dart';

/// Modelo auxiliar para plotar veículos (tanto da previsão do ponto quanto da posição da linha) no mapa
class MapaVeiculoPin {
  final String prefixo;
  final String letreiro;
  final bool acessivelPcD;
  final String? horarioChegada;
  final double latitude;
  final double longitude;

  const MapaVeiculoPin({
    required this.prefixo,
    required this.letreiro,
    required this.acessivelPcD,
    this.horarioChegada,
    required this.latitude,
    required this.longitude,
  });

  bool get possuiCoordenadas => latitude != 0.0 && longitude != 0.0;
}

/// Camada: Widgets (Componente Visual Reutilizável — Mapa Interativo de Pontos e Ônibus)
/// Responsabilidade Única: Renderizar um mapa interativo real (OpenStreetMap Slippy Tiles via
/// projeção Web Mercator, sem depender de plugins nativos) mostrando:
/// 1. O ponto de ônibus selecionado pelo cidadão (e de qual lado da via ele fica: B/C ou C/B).
/// 2. Os outros pontos próximos na mesma avenida (para o usuário comparar os lados da rua).
/// 3. Os ônibus se aproximando em tempo real com linha tracejada e distância em metros até o ponto.
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
  });

  /// Calcula a distância real em metros entre duas coordenadas GPS usando a Fórmula de Haversine
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

  static double _grausParaRadianos(double graus) => graus * (math.pi / 180.0);

  @override
  State<PontoMapWidget> createState() => _PontoMapWidgetState();
}

class _PontoMapWidgetState extends State<PontoMapWidget> {
  int _zoom = 16;
  late double _centerLat;
  late double _centerLon;

  @override
  void initState() {
    super.initState();
    _atualizarCentroPadrao();
  }

  @override
  void didUpdateWidget(covariant PontoMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paradaSelecionada?.codigoParada !=
            oldWidget.paradaSelecionada?.codigoParada ||
        widget.paradas.length != oldWidget.paradas.length) {
      _atualizarCentroPadrao();
    }
  }

  void _atualizarCentroPadrao() {
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas) {
      _centerLat = widget.paradaSelecionada!.latitude;
      _centerLon = widget.paradaSelecionada!.longitude;
      return;
    }
    final paradasValidas =
        widget.paradas.where((p) => p.possuiCoordenadas).toList();
    if (paradasValidas.isNotEmpty) {
      _centerLat = paradasValidas.first.latitude;
      _centerLon = paradasValidas.first.longitude;
      return;
    }
    final veiculosValidos =
        widget.veiculos.where((v) => v.possuiCoordenadas).toList();
    if (veiculosValidos.isNotEmpty) {
      _centerLat = veiculosValidos.first.latitude;
      _centerLon = veiculosValidos.first.longitude;
      return;
    }
    // Centro padrão: Av. Paulista / MASP (São Paulo)
    _centerLat = -23.561414;
    _centerLon = -46.655881;
  }

  void _centralizarNoPontoSelecionado() {
    setState(() {
      _zoom = 16;
      _atualizarCentroPadrao();
    });
  }

  void _enquadrarPontoEOnibus() {
    final veiculosValidos =
        widget.veiculos.where((v) => v.possuiCoordenadas).toList();
    if (widget.paradaSelecionada != null &&
        widget.paradaSelecionada!.possuiCoordenadas &&
        veiculosValidos.isNotEmpty) {
      final p = widget.paradaSelecionada!;
      final v = veiculosValidos.first;
      final dist = PontoMapWidget.calcularDistanciaMetros(
        p.latitude,
        p.longitude,
        v.latitude,
        v.longitude,
      );
      setState(() {
        _centerLat = (p.latitude + v.latitude) / 2;
        _centerLon = (p.longitude + v.longitude) / 2;
        if (dist > 4000) {
          _zoom = 13;
        } else if (dist > 1500) {
          _zoom = 14;
        } else {
          _zoom = 15;
        }
      });
    } else {
      _centralizarNoPontoSelecionado();
    }
  }

  // Conversão Web Mercator (Latitude/Longitude -> Pixel global no nível de zoom Z)
  static double _lonToGlobalX(double lon, int zoom) {
    final double n = math.pow(2.0, zoom).toDouble() * 256.0;
    return ((lon + 180.0) / 360.0) * n;
  }

  static double _latToGlobalY(double lat, int zoom) {
    final double n = math.pow(2.0, zoom).toDouble() * 256.0;
    final double latRad = lat * math.pi / 180.0;
    final double mercN =
        math.log(math.tan((math.pi / 4.0) + (latRad / 2.0)));
    return (0.5 - (mercN / (2.0 * math.pi))) * n;
  }

  static double _globalXToLon(double globalX, int zoom) {
    final double n = math.pow(2.0, zoom).toDouble() * 256.0;
    return (globalX / n) * 360.0 - 180.0;
  }

  static double _globalYToLat(double globalY, int zoom) {
    final double n = math.pow(2.0, zoom).toDouble() * 256.0;
    final double y = 0.5 - (globalY / n);
    final double latRad =
        2.0 * math.atan(math.exp(y * 2.0 * math.pi)) - (math.pi / 2.0);
    return latRad * 180.0 / math.pi;
  }

  void _moverMapaPorPixels(double dx, double dy) {
    final centerGlobalX = _lonToGlobalX(_centerLon, _zoom);
    final centerGlobalY = _latToGlobalY(_centerLat, _zoom);
    setState(() {
      _centerLon = _globalXToLon(centerGlobalX - dx, _zoom);
      _centerLat = _globalYToLat(centerGlobalY - dy, _zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final paradaAtual = widget.paradaSelecionada;
    final paradasComGps =
        widget.paradas.where((p) => p.possuiCoordenadas).take(12).toList();
    final veiculosComGps =
        widget.veiculos.where((v) => v.possuiCoordenadas).take(10).toList();

    // Calcula a distância do ônibus mais próximo até a parada selecionada
    double? menorDistanciaMetros;
    MapaVeiculoPin? onibusMaisProximo;
    if (paradaAtual != null && paradaAtual.possuiCoordenadas) {
      for (final v in veiculosComGps) {
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho do Mapa com Status de Ponto Correto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tituloMapa,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        paradaAtual != null
                            ? 'Ponto selecionado: ${paradaAtual.nomeParada} • ${paradaAtual.ladoDaViaExplicado}'
                            : 'Arraste o mapa ou toque nos pinos para conferir o lado certo da via',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (veiculosComGps.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: _enquadrarPontoEOnibus,
                    icon: const Icon(Icons.directions_bus, size: 15, color: Colors.white),
                    label: const Text(
                      'Enquadrar Ônibus',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Faixa de Distância do GPS do Celular até o Ponto Selecionado
          if (distanciaUsuarioAtePonto != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: distanciaUsuarioAtePonto <= 85
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  Icon(
                    distanciaUsuarioAtePonto <= 85
                        ? Icons.my_location
                        : Icons.directions_walk,
                    size: 18,
                    color: distanciaUsuarioAtePonto <= 85
                        ? const Color(0xFF15803D)
                        : AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      distanciaUsuarioAtePonto <= 85
                          ? '📍 GPS DO CELULAR: Você já está neste ponto! (${distanciaUsuarioAtePonto.round()}m de distância)'
                          : '📍 GPS DO CELULAR: Você está a ${PontoMapWidget.formatarDistancia(distanciaUsuarioAtePonto)} (~${math.max(1, (distanciaUsuarioAtePonto / 75).ceil())} min caminhando até ${paradaAtual?.nomeParada ?? "o ponto"})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: distanciaUsuarioAtePonto <= 85
                            ? const Color(0xFF14532D)
                            : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 2b. Faixa de Verificação: "Estou no ponto certo para o meu ônibus?"
          if (widget.linhaDestacada != null && widget.linhaDestacada!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: widget.linhaPassaNestePonto == true
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  Icon(
                    widget.linhaPassaNestePonto == true
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    color: widget.linhaPassaNestePonto == true
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.linhaPassaNestePonto == true
                          ? 'PONTO CORRETO CONFIRMADO: A linha ${widget.linhaDestacada} passa exatamente neste ponto (${paradaAtual?.nomeParada ?? ""})!'
                          : 'ATENÇÃO AO LADO DA RUA: A linha ${widget.linhaDestacada} não tem previsão imediata neste ponto. Toque nos outros pontos no mapa para checar o outro lado da via!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.linhaPassaNestePonto == true
                            ? const Color(0xFF14532D)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Área Visual do Mapa Interativo (OpenStreetMap Slippy Tiles + Pinos Interativos)
          SizedBox(
            height: 280,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final centerGlobalX = _lonToGlobalX(_centerLon, _zoom);
                final centerGlobalY = _latToGlobalY(_centerLat, _zoom);
                final topLeftGlobalX = centerGlobalX - (width / 2.0);
                final topLeftGlobalY = centerGlobalY - (height / 2.0);

                // Calcula quais tiles 256x256 do OpenStreetMap cobrem a tela atual
                final int startTileX = (topLeftGlobalX / 256.0).floor();
                final int endTileX = ((topLeftGlobalX + width) / 256.0).floor();
                final int startTileY = (topLeftGlobalY / 256.0).floor();
                final int endTileY = ((topLeftGlobalY + height) / 256.0).floor();
                final int maxTileIndex = (1 << _zoom) - 1;

                final List<Widget> tileWidgets = [];
                for (int tx = startTileX; tx <= endTileX; tx++) {
                  for (int ty = startTileY; ty <= endTileY; ty++) {
                    if (ty < 0 || ty > maxTileIndex) continue;
                    final int wrappedTx =
                        ((tx % (maxTileIndex + 1)) + (maxTileIndex + 1)) %
                            (maxTileIndex + 1);
                    final double left = (tx * 256.0) - topLeftGlobalX;
                    final double top = (ty * 256.0) - topLeftGlobalY;

                    tileWidgets.add(
                      Positioned(
                        left: left,
                        top: top,
                        width: 256,
                        height: 256,
                        child: Image.network(
                          'https://tile.openstreetmap.org/$_zoom/$wrappedTx/$ty.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 0.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.grid_4x4,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                // Converte uma coordenada (lat, lon) para Offset (x, y) dentro do card
                Offset latLonToLocalOffset(double lat, double lon) {
                  final gx = _lonToGlobalX(lon, _zoom);
                  final gy = _latToGlobalY(lat, _zoom);
                  return Offset(gx - topLeftGlobalX, gy - topLeftGlobalY);
                }

                Offset? offsetParadaAtual;
                if (paradaAtual != null && paradaAtual.possuiCoordenadas) {
                  offsetParadaAtual = latLonToLocalOffset(
                    paradaAtual.latitude,
                    paradaAtual.longitude,
                  );
                }

                Offset? offsetUsuarioGps;
                if (widget.usuarioLat != null && widget.usuarioLon != null) {
                  offsetUsuarioGps = latLonToLocalOffset(
                    widget.usuarioLat!,
                    widget.usuarioLon!,
                  );
                }

                final List<Offset> offsetsVeiculos = veiculosComGps
                    .map((v) => latLonToLocalOffset(v.latitude, v.longitude))
                    .toList();

                return GestureDetector(
                  onPanUpdate: (details) {
                    _moverMapaPorPixels(details.delta.dx, details.delta.dy);
                  },
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Fundo base caso os tiles estejam carregando
                      Container(color: const Color(0xFFE2E8F0)),

                      // Camada 1: Tiles de Rua do OpenStreetMap
                      ...tileWidgets,

                      // Camada 2: Linhas tracejadas ligando os ônibus em tempo real até o ponto selecionado
                      if (offsetParadaAtual != null && offsetsVeiculos.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _TrajetoOnibusPontoPainter(
                                pontoOffset: offsetParadaAtual,
                                veiculosOffsets: offsetsVeiculos,
                              ),
                            ),
                          ),
                        ),

                      // Camada 3: Pinos dos Pontos de Ônibus Próximos (Não selecionados)
                      ...paradasComGps
                          .where((p) => p.codigoParada != paradaAtual?.codigoParada)
                          .map((p) {
                        final pos = latLonToLocalOffset(p.latitude, p.longitude);
                        if (pos.dx < -40 ||
                            pos.dx > width + 40 ||
                            pos.dy < -40 ||
                            pos.dy > height + 40) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          left: pos.dx - 18,
                          top: pos.dy - 36,
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onSelecionarParada != null) {
                                widget.onSelecionarParada!(p);
                              }
                            },
                            child: Tooltip(
                              message:
                                  'Toque para ver este ponto: ${p.nomeParada} (${p.endereco})',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    child: Text(
                                      p.nomeParada.isEmpty
                                          ? '#${p.codigoParada}'
                                          : (p.nomeParada.length > 10
                                              ? '${p.nomeParada.substring(0, 10)}…'
                                              : p.nomeParada),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF475569),
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Camada 4: Pinos dos Ônibus em Tempo Real (GPS SPTrans)
                      ...veiculosComGps.map((v) {
                        final pos = latLonToLocalOffset(v.latitude, v.longitude);
                        if (pos.dx < -60 ||
                            pos.dx > width + 60 ||
                            pos.dy < -60 ||
                            pos.dy > height + 60) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          left: pos.dx - 42,
                          top: pos.dy - 26,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: v.acessivelPcD
                                  ? AppTheme.secondaryTeal
                                  : AppTheme.accentAmber,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  v.acessivelPcD
                                      ? Icons.accessible
                                      : Icons.directions_bus,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '🚌 ${v.prefixo}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Camada 5: Pino Principal Destacado — O Ponto Selecionado pelo Usuário
                      if (paradaAtual != null && offsetParadaAtual != null)
                        Positioned(
                          left: offsetParadaAtual.dx - 65,
                          top: offsetParadaAtual.dy - 58,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxWidth: 130),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'VOCÊ: ${paradaAtual.nomeParada.isEmpty ? "Parada #${paradaAtual.codigoParada}" : paradaAtual.nomeParada}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.person_pin_circle_rounded,
                                color: AppTheme.primaryBlue,
                                size: 36,
                              ),
                            ],
                          ),
                        ),

                      // Camada 5b: Pino do GPS Atual do Celular do Usuário
                      if (offsetUsuarioGps != null &&
                          offsetUsuarioGps.dx >= -40 &&
                          offsetUsuarioGps.dx <= width + 40 &&
                          offsetUsuarioGps.dy >= -40 &&
                          offsetUsuarioGps.dy <= height + 40)
                        Positioned(
                          left: offsetUsuarioGps.dx - 38,
                          top: offsetUsuarioGps.dy - 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Seu GPS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Camada 6: Botões de Zoom (+ / - / Centralizar) no canto direito
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Column(
                          children: [
                            _MapControlIconButton(
                              icon: Icons.add,
                              tooltip: 'Aproximar rua (Zoom +)',
                              onTap: () {
                                if (_zoom < 18) setState(() => _zoom++);
                              },
                            ),
                            const SizedBox(height: 6),
                            _MapControlIconButton(
                              icon: Icons.remove,
                              tooltip: 'Afastar rua (Zoom -)',
                              onTap: () {
                                if (_zoom > 12) setState(() => _zoom--);
                              },
                            ),
                            const SizedBox(height: 6),
                            _MapControlIconButton(
                              icon: Icons.my_location,
                              tooltip: 'Centralizar no ponto selecionado',
                              onTap: _centralizarNoPontoSelecionado,
                            ),
                          ],
                        ),
                      ),

                      // Camada 7: Selo de Distância em Tempo Real no canto inferior esquerdo
                      if (menorDistanciaMetros != null && onibusMaisProximo != null)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.radar,
                                  color: Color(0xFF4ADE80),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ônibus nº ${onibusMaisProximo.prefixo} está a '
                                    '${PontoMapWidget.formatarDistancia(menorDistanciaMetros)}'
                                    '${onibusMaisProximo.horarioChegada != null && onibusMaisProximo.horarioChegada!.isNotEmpty ? " • Chega às ${onibusMaisProximo.horarioChegada}" : ""}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 4. Rodapé Explicativo (Legenda + Guia de Lado da Rua B/C vs C/B)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    const _LegendItem(
                      color: AppTheme.primaryBlue,
                      icon: Icons.person_pin_circle_rounded,
                      label: 'Ponto Selecionado',
                    ),
                    const _LegendItem(
                      color: Color(0xFF475569),
                      icon: Icons.location_on,
                      label: 'Outros Pontos da Via (toque para trocar)',
                    ),
                    const _LegendItem(
                      color: AppTheme.secondaryTeal,
                      icon: Icons.accessible,
                      label: 'Ônibus PcD no Mapa',
                    ),
                  ],
                ),
                if (paradaAtual != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '💡 Dica para não errar o lado da rua: "${paradaAtual.nomeParada}" fica em ${paradaAtual.endereco} (${paradaAtual.ladoDaViaExplicado}). '
                    'Nas paradas da SPTrans, "B/C" significa sentido Bairro ➔ Centro e "C/B" significa sentido Centro ➔ Bairro.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _TrajetoOnibusPontoPainter extends CustomPainter {
  final Offset pontoOffset;
  final List<Offset> veiculosOffsets;

  _TrajetoOnibusPontoPainter({
    required this.pontoOffset,
    required this.veiculosOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final vOffset in veiculosOffsets) {
      _drawDashedLine(canvas, vOffset, pontoOffset, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final double ux = dx / distance;
    final double uy = dy / distance;
    double start = 0.0;
    while (start < distance) {
      final double end = math.min(start + dashWidth, distance);
      canvas.drawLine(
        Offset(p1.dx + ux * start, p1.dy + uy * start),
        Offset(p1.dx + ux * end, p1.dy + uy * end),
        paint,
      );
      start += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TrajetoOnibusPontoPainter oldDelegate) {
    return oldDelegate.pontoOffset != pontoOffset ||
        oldDelegate.veiculosOffsets.length != veiculosOffsets.length;
  }
}
