import 'dart:async';
import 'dart:js_interop';

@JS('navigator.geolocation.getCurrentPosition')
external void _getCurrentPosition(
  JSFunction successCallback,
  JSFunction errorCallback, [
  _PositionOptions? options,
]);

extension type _PositionOptions._(JSObject _) implements JSObject {
  external factory _PositionOptions({
    bool enableHighAccuracy,
    int timeout,
    int maximumAge,
  });
}

extension type _GeolocationPosition(JSObject _) implements JSObject {
  external _GeolocationCoordinates get coords;
}

extension type _GeolocationCoordinates(JSObject _) implements JSObject {
  external double get latitude;
  external double get longitude;
}

/// Captura a localização GPS real do celular/navegador via API oficial W3C Geolocation
/// com `enableHighAccuracy: true` e `maximumAge: 0` para exigir a maior precisão disponível.
Future<({double latitude, double longitude})?> obterCoordenadasNativas() async {
  final completer = Completer<({double latitude, double longitude})?>();

  void onSuccess(_GeolocationPosition pos) {
    if (!completer.isCompleted) {
      completer.complete((
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude,
      ));
    }
  }

  void onError(JSAny? _) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  try {
    _getCurrentPosition(
      onSuccess.toJS,
      onError.toJS,
      _PositionOptions(
        enableHighAccuracy: true,
        timeout: 8000,
        maximumAge: 0,
      ),
    );
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  return completer.future.timeout(
    const Duration(seconds: 9),
    onTimeout: () => null,
  );
}
