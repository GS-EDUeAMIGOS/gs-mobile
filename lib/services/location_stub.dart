import 'package:geolocator/geolocator.dart';

/// Implementação nativa para dispositivos móveis (Android/iOS) e Desktop via plugin Geolocator.
/// Solicita permissão em tempo de execução (Runtime Permission) quando necessário e retorna
/// as coordenadas reais do sensor GPS, ou `null` caso o GPS esteja desativado, a permissão
/// seja negada ou o código esteja rodando em ambiente de teste sem MethodChannel nativo.
Future<({double latitude, double longitude})?> obterCoordenadasNativas() async {
  try {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      return null;
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return null;
    }

    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return (latitude: posicao.latitude, longitude: posicao.longitude);
  } catch (_) {
    // Em ambientes de teste (flutter test) ou plataformas sem suporte nativo,
    // retorna null graciosamente para acionar o fallback controlado.
    return null;
  }
}
