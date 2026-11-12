import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/main.dart';

void main() {
  testWidgets('Renderiza a tela inicial de Login do ViaCidada', (WidgetTester tester) async {
    await tester.pumpWidget(const ViaCidadaApp());

    expect(find.text('ViaCidadã'), findsOneWidget);
    expect(find.text('Entrar na Plataforma'), findsOneWidget);
  });
}
