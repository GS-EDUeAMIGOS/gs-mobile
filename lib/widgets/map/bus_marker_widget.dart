import 'package:flutter/material.dart';
import '../../theme/map_theme.dart';

/// Modelo auxiliar para plotar veículos (tanto da previsão do ponto quanto da posição da linha) no mapa.
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

/// Camada: Widgets / Map (Marcador Modular de Veículo em Tempo Real)
/// Responsabilidade Única: Renderizar o pino de um ônibus no mapa com alto contraste
/// no tema escuro, diferenciando visualmente veículos acessíveis PcD (#10B981 + ♿)
/// de veículos sem elevador (#F59E0B), com suporte a toque e tooltip informativo.
class BusMarkerWidget extends StatelessWidget {
  final MapaVeiculoPin veiculo;
  final VoidCallback? onTap;
  final bool compacto;

  const BusMarkerWidget({
    super.key,
    required this.veiculo,
    this.onTap,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color corFundo = veiculo.acessivelPcD
        ? MapTheme.busPcdEmerald
        : MapTheme.busStandardAmber;

    final String statusPcd =
        veiculo.acessivelPcD ? 'Com Elevador PcD (Acessível)' : 'Sem Elevador PcD';
    final String horarioInfo =
        veiculo.horarioChegada != null && veiculo.horarioChegada!.isNotEmpty
            ? '\nPrevisão/GPS: ${veiculo.horarioChegada}'
            : '';
    final String linhaInfo =
        veiculo.letreiro.isNotEmpty ? 'Linha ${veiculo.letreiro} • ' : '';

    return Tooltip(
      message: '$linhaInfo' 'Ônibus ${veiculo.prefixo}\n$statusPcd$horarioInfo',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compacto ? 6 : 8,
                vertical: compacto ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: corFundo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MapTheme.textPrimary, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: corFundo.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    veiculo.acessivelPcD
                        ? Icons.accessible
                        : Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: compacto ? 12 : 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    veiculo.prefixo.isEmpty ? 'BUS' : veiculo.prefixo,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compacto ? 9.5 : 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!compacto && veiculo.letreiro.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          veiculo.letreiro,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            CustomPaint(
              size: const Size(10, 5),
              painter: _MarkerPointerPainter(color: corFundo),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerPointerPainter extends CustomPainter {
  final Color color;

  const _MarkerPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
