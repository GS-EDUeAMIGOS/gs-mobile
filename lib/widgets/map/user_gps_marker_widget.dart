import 'package:flutter/material.dart';
import '../../theme/map_theme.dart';

/// Camada: Widgets / Map (Marcador de Localização GPS do Usuário)
/// Responsabilidade Única: Exibir o ponto exato do cidadão em #38BDF8 (Ciano Brilhante)
/// com halo circular translúcido pulsante estilo apps de mobilidade urbana.
class UserGpsMarkerWidget extends StatefulWidget {
  final bool animarPulso;

  const UserGpsMarkerWidget({
    super.key,
    this.animarPulso = true,
  });

  @override
  State<UserGpsMarkerWidget> createState() => _UserGpsMarkerWidgetState();
}

class _UserGpsMarkerWidgetState extends State<UserGpsMarkerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.animarPulso) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant UserGpsMarkerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animarPulso && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.animarPulso && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sua localização atual (GPS)',
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final double t = _pulseController.value;
          final double haloSize = 26.0 + (18.0 * t);
          final double haloAlpha = 0.34 - (0.20 * t);

          return SizedBox(
            width: 92,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: MapTheme.surfaceDark.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: MapTheme.userGpsCyan,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_pin_circle,
                          size: 11,
                          color: MapTheme.userGpsCyan,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'VOCÊ',
                          style: TextStyle(
                            color: MapTheme.textPrimary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: haloSize,
                  height: haloSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MapTheme.userGpsCyan.withValues(alpha: haloAlpha),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MapTheme.userGpsCyan,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: MapTheme.userGpsCyan.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
