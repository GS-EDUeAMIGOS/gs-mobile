import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Perfil de deslocamento suportado pelo roteador viário.
enum StreetRouteProfile {
  /// Trajeto pelas vias e avenidas para ônibus.
  driving('driving'),

  /// Trajeto a pé por calçadas, travessias e ruas para o cidadão até o ponto.
  foot('foot');

  final String osrmProfile;
  const StreetRouteProfile(this.osrmProfile);
}

/// Camada: Services (Roteamento Viário Real — Street-Level Routing)
/// Responsabilidade Única: Converter pontos geográficos (paradas ou GPS ➔ ponto)
/// em polilinhas que seguem o traçado real das ruas e avenidas via OSRM
/// (OpenStreetMap), com cache em memória e fallback seguro offline.
class StreetRouteService {
  StreetRouteService._();

  static final StreetRouteService instance = StreetRouteService._();

  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1';
  static const Duration _timeout = Duration(seconds: 4);
  static const double _maxSaltoOnibusMetros = 6500.0;
  static const double _maxDistanciaCaminhadaMetros = 3500.0;

  final Map<String, List<LatLng>> _cache = {};

  /// Limpa o cache em memória (útil em testes ou troca de contexto).
  void limparCache() => _cache.clear();

  /// Calcula o caminho real a pé pelas ruas entre a posição do cidadão e o ponto de embarque.
  /// Retorna lista vazia se a distância for superior a 3,5 km (fora de alcance a pé).
  Future<List<LatLng>> obterRotaCaminhada({
    required LatLng origemUsuario,
    required LatLng destinoPonto,
    http.Client? client,
  }) async {
    final distMetros = _calcularDistanciaMetros(origemUsuario, destinoPonto);
    if (distMetros < 12.0 || distMetros > _maxDistanciaCaminhadaMetros) {
      return const [];
    }

    return obterRotaPorRuas(
      waypoints: [origemUsuario, destinoPonto],
      profile: StreetRouteProfile.foot,
      client: client,
    );
  }

  /// Calcula a polilinha real pelas ruas/avenidas passando pelos [waypoints] informados.
  /// Usa cache em memória e cai para fallback seguro caso o servidor OSRM esteja indisponível.
  Future<List<LatLng>> obterRotaPorRuas({
    required List<LatLng> waypoints,
    StreetRouteProfile profile = StreetRouteProfile.driving,
    http.Client? client,
  }) async {
    final pontosValidos = _filtrarPontosValidos(waypoints, profile: profile);
    if (pontosValidos.length < 2) {
      return const [];
    }

    final chave = _gerarChaveCache(pontosValidos, profile);
    final emCache = _cache[chave];
    if (emCache != null) {
      return emCache;
    }

    final httpClient = client ?? http.Client();
    final deveFecharClient = client == null;

    try {
      final coordsParam = pontosValidos
          .map(
            (p) =>
                '${p.longitude.toStringAsFixed(5)},${p.latitude.toStringAsFixed(5)}',
          )
          .join(';');

      final uri = Uri.parse(
        '$_osrmBaseUrl/${profile.osrmProfile}/$coordsParam'
        '?overview=full&geometries=geojson&steps=false',
      );

      final response = await httpClient.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rotaExtraida = _extrairGeoJsonCoordinates(decoded);
        if (rotaExtraida.length >= 2) {
          _cache[chave] = rotaExtraida;
          return rotaExtraida;
        }
      }
    } catch (_) {
      // Silencioso: em ambiente offline ou testes sem rede, usa o fallback geométrico.
    } finally {
      if (deveFecharClient) {
        httpClient.close();
      }
    }

    return gerarTrajetoFallback(pontosValidos);
  }

  /// Extrai e converte coordenadas GeoJSON (`[lon, lat]`) para `LatLng(lat, lon)`.
  static List<LatLng> _extrairGeoJsonCoordinates(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return const [];
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return const [];

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) return const [];
    final geometry = firstRoute['geometry'];
    if (geometry is! Map<String, dynamic>) return const [];
    final coords = geometry['coordinates'];
    if (coords is! List) return const [];

    final List<LatLng> resultado = [];
    for (final item in coords) {
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
          resultado.add(LatLng(lat, lon));
        }
      }
    }
    return resultado;
  }

  /// Remove coordenadas nulas/duplicadas e corta saltos absurdos que cruzariam a cidade em linha reta.
  static List<LatLng> _filtrarPontosValidos(
    List<LatLng> waypoints, {
    required StreetRouteProfile profile,
  }) {
    final List<LatLng> limpos = [];
    for (final p in waypoints) {
      if (p.latitude == 0.0 && p.longitude == 0.0) continue;
      if (limpos.isEmpty) {
        limpos.add(p);
        continue;
      }
      final dist = _calcularDistanciaMetros(limpos.last, p);
      if (dist < 15.0) continue; // Ignora pontos praticamente idênticos

      if (profile == StreetRouteProfile.driving && dist > _maxSaltoOnibusMetros) {
        continue; // Evita ligar bairros desconexos com risco reto gigante
      }
      limpos.add(p);
    }

    // Limita a 15 waypoints para respeitar URLs enxutas na API pública OSRM
    if (limpos.length <= 15) return limpos;
    final List<LatLng> amostrados = [];
    for (int i = 0; i < 15; i++) {
      final idx = (i * (limpos.length - 1) / 14).round();
      amostrados.add(limpos[idx]);
    }
    return amostrados;
  }

  /// Fallback geométrico quando offline: suaviza curvas entre múltiplos pontos
  /// usando subdivisão de Chaikin para evitar quinas secas artificiais.
  static List<LatLng> gerarTrajetoFallback(List<LatLng> pontos) {
    if (pontos.length < 3) return List<LatLng>.unmodifiable(pontos);

    final List<LatLng> suavizado = [pontos.first];
    for (int i = 0; i < pontos.length - 1; i++) {
      final a = pontos[i];
      final b = pontos[i + 1];
      if (i > 0) {
        suavizado.add(
          LatLng(
            a.latitude * 0.75 + b.latitude * 0.25,
            a.longitude * 0.75 + b.longitude * 0.25,
          ),
        );
      }
      if (i < pontos.length - 2) {
        suavizado.add(
          LatLng(
            a.latitude * 0.25 + b.latitude * 0.75,
            a.longitude * 0.25 + b.longitude * 0.75,
          ),
        );
      }
    }
    suavizado.add(pontos.last);
    return List<LatLng>.unmodifiable(suavizado);
  }

  String _gerarChaveCache(List<LatLng> pontos, StreetRouteProfile profile) {
    final coordsKey = pontos
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
        )
        .join('|');
    return '${profile.osrmProfile}:$coordsKey';
  }

  static double _calcularDistanciaMetros(LatLng a, LatLng b) {
    const double raioTerra = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180.0);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180.0);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * (math.pi / 180.0)) *
            math.cos(b.latitude * (math.pi / 180.0)) *
            sinLon *
            sinLon;
    return raioTerra * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
