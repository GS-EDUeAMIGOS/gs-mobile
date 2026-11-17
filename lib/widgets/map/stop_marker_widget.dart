import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/olho_vivo_model.dart';
import '../../theme/map_theme.dart';

/// Grupo de paradas próximas agregado para exibição em zoom afastado (clustering).
class StopClusterGroup {
  final LatLng centro;
  final List<ParadaResumoModel> paradas;

  const StopClusterGroup({
    required this.centro,
    required this.paradas,
  });

  int get quantidade => paradas.length;
  bool get isCluster => paradas.length > 1;
}

/// Camada: Widgets / Map (Utilitário de Clustering Espacial de Paradas)
/// Responsabilidade Única: Agrupar paradas próximas quando o zoom está afastado
/// (ex.: zoom <= 14), mantendo Terminais/Estações e a Parada Selecionada em destaque.
class StopClusterHelper {
  StopClusterHelper._();

  static List<StopClusterGroup> agruparParadas({
    required List<ParadaResumoModel> paradas,
    required double zoom,
    int? codigoParadaSelecionada,
  }) {
    final validas = paradas.where((p) => p.possuiCoordenadas).toList();
    if (validas.isEmpty) return const [];

    // Raio de agrupamento em graus aproximados conforme nível de zoom
    // zoom <= 12: ~1.8km | zoom 13: ~900m | zoom 14: ~450m
    final double raioGraus = zoom <= 12
        ? 0.016
        : zoom <= 13
            ? 0.0085
            : 0.0045;

    final List<ParadaResumoModel> comuns = [];
    for (final p in validas) {
      final isSel = p.codigoParada == codigoParadaSelecionada;
      final isTerm = MapTheme.isTerminalOuEstacao(p);
      if (!isSel && !isTerm) {
        comuns.add(p);
      }
    }

    final List<bool> visitado = List<bool>.filled(comuns.length, false);
    final List<StopClusterGroup> grupos = [];

    for (int i = 0; i < comuns.length; i++) {
      if (visitado[i]) continue;
      visitado[i] = true;
      final base = comuns[i];
      final clusterList = <ParadaResumoModel>[base];

      for (int j = i + 1; j < comuns.length; j++) {
        if (visitado[j]) continue;
        final cand = comuns[j];
        final dLat = base.latitude - cand.latitude;
        final dLon = base.longitude - cand.longitude;
        final distSq = dLat * dLat + dLon * dLon;
        if (distSq <= raioGraus * raioGraus) {
          visitado[j] = true;
          clusterList.add(cand);
        }
      }

      double sumLat = 0;
      double sumLon = 0;
      for (final item in clusterList) {
        sumLat += item.latitude;
        sumLon += item.longitude;
      }
      grupos.add(
        StopClusterGroup(
          centro: LatLng(
            sumLat / clusterList.length,
            sumLon / clusterList.length,
          ),
          paradas: clusterList,
        ),
      );
    }

    return grupos;
  }

  /// Calcula um nível de zoom ideal para abrir um cluster ao ser tocado.
  static double proximoZoomAoAbrirCluster(double zoomAtual) {
    return math.min(MapTheme.detailedZoomThreshold, zoomAtual + 2.0);
  }
}

/// Camada: Widgets / Map (Marcador Modular de Parada, Terminal ou Cluster)
/// Responsabilidade Única: Renderizar pontos comuns, paradas selecionadas (com badge
/// B/C ou C/B), terminais/estações (#A855F7) e círculos numéricos de cluster.
class StopMarkerWidget extends StatelessWidget {
  final ParadaResumoModel parada;
  final bool selecionada;
  final bool isTerminal;
  final bool mostrarRotulo;
  final VoidCallback? onTap;

  const StopMarkerWidget({
    super.key,
    required this.parada,
    this.selecionada = false,
    this.isTerminal = false,
    this.mostrarRotulo = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? siglaVia = MapTheme.extrairSiglaLadoVia(parada);
    final String nomeCurto = parada.nomeParada.isEmpty
        ? 'Parada #${parada.codigoParada}'
        : (parada.nomeParada.length > 18
            ? '${parada.nomeParada.substring(0, 18)}…'
            : parada.nomeParada);

    if (selecionada) {
      return Tooltip(
        message:
            'Seu Ponto: ${parada.nomeParada} (${parada.ladoDaViaExplicado})\n${parada.endereco}',
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: MapTheme.surfaceDark.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MapTheme.stopSelectedBlue,
                    width: 1.4,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hail_rounded,
                      size: 11,
                      color: MapTheme.userGpsCyan,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'SEU PONTO',
                      style: TextStyle(
                        color: MapTheme.textPrimary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 175),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MapTheme.stopSelectedBlue,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MapTheme.textPrimary, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: MapTheme.stopSelectedBlue.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (siglaVia != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          siglaVia,
                          style: const TextStyle(
                            color: MapTheme.stopSelectedBlue,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        nomeCurto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: MapTheme.stopSelectedBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: MapTheme.stopSelectedBlue.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isTerminal ? Icons.directions_transit : Icons.directions_bus,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isTerminal) {
      return Tooltip(
        message: 'Terminal / Estação: ${parada.nomeParada}\n${parada.endereco}',
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mostrarRotulo)
                Container(
                  constraints: const BoxConstraints(maxWidth: 135),
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MapTheme.surfaceDark.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: MapTheme.terminalPurple, width: 1.2),
                  ),
                  child: Text(
                    nomeCurto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MapTheme.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: MapTheme.terminalPurple,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MapTheme.textPrimary, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: MapTheme.terminalPurple.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_transit,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ponto de ônibus padrão
    return Tooltip(
      message: '${parada.nomeParada} (${parada.ladoDaViaExplicado})\nToque para selecionar',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarRotulo)
              Container(
                constraints: const BoxConstraints(maxWidth: 130),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: MapTheme.surfaceCardDark.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MapTheme.stopDefault, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (siglaVia != null) ...[
                      Text(
                        '$siglaVia ',
                        style: const TextStyle(
                          color: MapTheme.userGpsCyan,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        nomeCurto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MapTheme.textPrimary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: mostrarRotulo ? 16 : 13,
              height: mostrarRotulo ? 16 : 13,
              decoration: BoxDecoration(
                color: MapTheme.surfaceDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: MapTheme.stopDefaultBorder,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: MapTheme.stopDefault,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marcador numérico para agrupar múltiplas paradas em zoom afastado.
class StopClusterMarkerWidget extends StatelessWidget {
  final int quantidade;
  final VoidCallback onTap;

  const StopClusterMarkerWidget({
    super.key,
    required this.quantidade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$quantidade pontos agrupados — toque para aproximar',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MapTheme.surfaceCardDark,
            shape: BoxShape.circle,
            border: Border.all(color: MapTheme.polylineCoreNeon, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: MapTheme.polylineCoreNeon.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '+$quantidade',
              style: const TextStyle(
                color: MapTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
