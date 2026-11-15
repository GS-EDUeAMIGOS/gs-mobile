import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/olho_vivo_model.dart';

/// Camada: Theme (Identidade Visual do Mapa — Dark Transit UI)
/// Responsabilidade Única: Centralizar a paleta semântica de alto contraste do mapa,
/// URLs de tiles (CartoDB Dark Matter + fallback OpenStreetMap), níveis de zoom
/// e regras de classificação de Terminais/Estações.
class MapTheme {
  MapTheme._();

  // ===========================================================================
  // 1. PALETA CITIZENTECH DARK MOBILITY
  // ===========================================================================
  static const Color mapBackground = Color(0xFF0B1120);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceCardDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // GPS do Usuário
  static const Color userGpsCyan = Color(0xFF38BDF8);

  // Paradas de Ônibus
  static const Color stopDefault = Color(0xFF94A3B8);
  static const Color stopDefaultBorder = Color(0xFFF8FAFC);
  static const Color stopSelectedBlue = Color(0xFF3B82F6);
  static const Color terminalPurple = Color(0xFFA855F7);

  // Polyline da Linha / Rota Selecionada (Borda escura + Núcleo Ciano Neon)
  static const Color polylineBorderDark = Color(0xFF083344);
  static const Color polylineCoreNeon = Color(0xFF06B6D4);
  static const double polylineBorderWidth = 7.0;
  static const double polylineCoreWidth = 4.0;

  // Frota em Tempo Real (Diferenciação clara PcD vs Comum)
  static const Color busPcdEmerald = Color(0xFF10B981);
  static const Color busStandardAmber = Color(0xFFF59E0B);

  // ===========================================================================
  // 2. PROVEDORES DE TILES E FALLBACK ESCURO
  // ===========================================================================
  static const String userAgentPackageName = 'br.com.viacidada.mobile';

  /// Provedor primário: CartoDB Dark Matter (limpo, sem poluição comercial)
  static const String cartoDarkUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  /// Provedor alternativo / claro: OpenStreetMap padrão
  static const String osmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Matriz de inversão com preservação de matiz para transformar tiles OSM claros
  /// em tema escuro caso o CartoDB falhe ou seja usado como fallback escuro.
  static const ColorFilter osmDarkColorFilter = ColorFilter.matrix(<double>[
    0.574, -1.430, -0.144, 0, 255,
    -0.426, -0.430, -0.144, 0, 255,
    -0.426, -1.430, 0.856, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  // ===========================================================================
  // 3. CONSTANTES DE ZOOM E CENTRO PADRÃO
  // ===========================================================================
  static const double minZoom = 11.0;
  static const double maxZoom = 18.0;
  static const double defaultZoom = 16.0;

  /// Abaixo ou igual a 14: agrupa paradas próximas em clusters numéricos
  static const double clusterZoomThreshold = 14.0;

  /// Entre 14 e 16: exibe pinos compactos (rótulo fixo só na parada selecionada)
  static const double detailedZoomThreshold = 16.0;

  /// Centro padrão: Av. Paulista / MASP (São Paulo)
  static const LatLng defaultCenter = LatLng(-23.561414, -46.655881);

  // ===========================================================================
  // 4. CLASSIFICAÇÃO DE TERMINAIS / ESTAÇÕES
  // ===========================================================================
  static const List<String> _termosTerminalOuEstacao = [
    'TERMINAL',
    'TERM',
    'ESTACAO',
    'EST.',
    'METRO',
    'CPTM',
  ];

  /// Identifica automaticamente se a parada é um Terminal de Ônibus ou Estação Metrô/CPTM.
  static bool isTerminalOuEstacao(ParadaResumoModel parada) {
    final texto = _normalizarTexto('${parada.nomeParada} ${parada.endereco}');
    for (final termo in _termosTerminalOuEstacao) {
      if (texto.contains(termo)) {
        return true;
      }
    }
    return false;
  }

  /// Extrai a sigla compacta do lado da via (`B/C` ou `C/B`), se presente no nome da parada.
  static String? extrairSiglaLadoVia(ParadaResumoModel parada) {
    final upper = parada.nomeParada.toUpperCase();
    if (upper.contains('B/C')) return 'B/C';
    if (upper.contains('C/B')) return 'C/B';
    return null;
  }

  static String _normalizarTexto(String input) {
    return input
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ç', 'C');
  }
}
