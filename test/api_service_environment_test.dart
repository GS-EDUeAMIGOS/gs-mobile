import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viacidada_mobile/screens/login_screen.dart';
import 'package:viacidada_mobile/services/api_service.dart';
import 'package:viacidada_mobile/theme/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.instance.setEnvironment(ApiEnvironment.azure);
  });

  test('ApiService usa URL da Azure por padrao e alterna para localhost quando solicitado', () async {
    expect(ApiService.instance.environment, ApiEnvironment.azure);
    expect(
      ApiService.instance.baseUrl,
      'https://viacidada-3a46802b7054.eastus.cloudapp.azure.com/api',
    );

    await ApiService.instance.setEnvironment(ApiEnvironment.local);
    expect(ApiService.instance.environment, ApiEnvironment.local);
    expect(ApiService.instance.baseUrl, ApiService.localBaseUrl);
    expect(ApiService.instance.baseUrl, endsWith('/api'));
  });

  testWidgets('LoginScreen permite alternar servidor da API entre Azure e Localhost',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('Azure (Nuvem)'), findsOneWidget);
    expect(find.text('Localhost (8080)'), findsOneWidget);
    expect(
      find.text('https://viacidada-3a46802b7054.eastus.cloudapp.azure.com/api'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Localhost (8080)'));
    await tester.tap(find.text('Localhost (8080)'));
    await tester.pumpAndSettle();

    expect(ApiService.instance.environment, ApiEnvironment.local);
    expect(find.text(ApiService.localBaseUrl), findsOneWidget);
  });
}
