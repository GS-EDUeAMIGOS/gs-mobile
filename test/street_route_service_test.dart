import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:viacidada_mobile/services/street_route_service.dart';

void main() {
  setUp(() {
    StreetRouteService.instance.limparCache();
  });

  test('Converte geometria GeoJSON do OSRM e reutiliza cache em memoria',
      () async {
    int chamadasHttp = 0;
    final mockClient = MockClient((request) async {
      chamadasHttp++;
      expect(request.url.path, contains('/route/v1/driving/'));
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [-46.6558, -23.5614],
                  [-46.6540, -23.5625],
                  [-46.6520, -23.5638],
                ],
              },
            }
          ],
        }),
        200,
      );
    });

    const waypoints = [
      LatLng(-23.5614, -46.6558),
      LatLng(-23.5638, -46.6520),
    ];

    final primeira = await StreetRouteService.instance.obterRotaPorRuas(
      waypoints: waypoints,
      profile: StreetRouteProfile.driving,
      client: mockClient,
    );
    final segunda = await StreetRouteService.instance.obterRotaPorRuas(
      waypoints: waypoints,
      profile: StreetRouteProfile.driving,
      client: mockClient,
    );

    expect(primeira.length, 3);
    expect(primeira.first.latitude, closeTo(-23.5614, 0.0001));
    expect(primeira.first.longitude, closeTo(-46.6558, 0.0001));
    expect(segunda, equals(primeira));
    expect(chamadasHttp, 1);
  });

  test('Retorna fallback suavizado quando OSRM falha ou esta offline',
      () async {
    final mockClient = MockClient((_) async => http.Response('Erro', 503));

    const waypoints = [
      LatLng(-23.5614, -46.6558),
      LatLng(-23.5630, -46.6540),
      LatLng(-23.5650, -46.6510),
    ];

    final rota = await StreetRouteService.instance.obterRotaPorRuas(
      waypoints: waypoints,
      client: mockClient,
    );

    expect(rota.length, greaterThan(waypoints.length));
    expect(rota.first, waypoints.first);
    expect(rota.last, waypoints.last);
  });

  test('Nao calcula rota a pe quando usuario esta a mais de 3.5 km do ponto',
      () async {
    int chamadasHttp = 0;
    final mockClient = MockClient((_) async {
      chamadasHttp++;
      return http.Response('{}', 200);
    });

    final rota = await StreetRouteService.instance.obterRotaCaminhada(
      origemUsuario: const LatLng(-23.5614, -46.6558),
      destinoPonto: const LatLng(-23.6200, -46.7000),
      client: mockClient,
    );

    expect(rota, isEmpty);
    expect(chamadasHttp, 0);
  });
}
