import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viacidada_mobile/models/ocorrencia_model.dart';
import 'package:viacidada_mobile/screens/occurrence_detail_screen.dart';
import 'package:viacidada_mobile/theme/app_theme.dart';
import 'package:viacidada_mobile/theme/theme_controller.dart';
import 'package:viacidada_mobile/widgets/occurrence_card.dart';
import 'package:viacidada_mobile/widgets/theme_selector_button.dart';

void main() {
  test('OcorrenciaModel separa a linha informada da descrição visível', () {
    const ocorrencia = OcorrenciaModel(
      usuarioId: 2,
      titulo: 'Atraso na linha',
      descricao: '[Linha: Vila Liviero]\nÔnibus atrasado há 30 minutos.',
      tipo: TipoOcorrencia.ATRASO,
    );

    expect(ocorrencia.linhaEmDestaque, 'Vila Liviero');
    expect(ocorrencia.descricaoSemTagLinha, 'Ônibus atrasado há 30 minutos.');
  });

  testWidgets('OccurrenceCard destaca a linha e mantém o prefixo secundário', (
    WidgetTester tester,
  ) async {
    const ocorrencia = OcorrenciaModel(
      id: 9,
      usuarioId: 2,
      titulo: 'Lotação excessiva',
      descricao: '[Linha: 5031-10 • Vila Liviero]\nVeículo muito lotado.',
      tipo: TipoOcorrencia.LOTACAO_EXCESSIVA,
      prefixoVeiculo: '51215',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: OccurrenceCard(ocorrencia: ocorrencia)),
      ),
    );

    expect(find.text('Linha: 5031-10 • Vila Liviero'), findsOneWidget);
    expect(find.text('Ônibus nº 51215'), findsOneWidget);
    expect(find.textContaining('[Linha:'), findsNothing);
  });

  testWidgets(
    'ThemeSelectorButton exibe icones do menu flutuante com alto contraste no tema claro',
    (WidgetTester tester) async {
      final controller = ThemeController(initialMode: ThemeMode.light);

      await tester.pumpWidget(
        ThemeControllerScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Teste'),
                actions: const [ThemeSelectorButton()],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ThemeSelectorButton));
      await tester.pumpAndSettle();

      final sunIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(PopupMenuItem<ThemeMode>),
          matching: find.byIcon(Icons.light_mode_outlined),
        ),
      );
      expect(sunIcon.color, isNot(Colors.white));
      expect(sunIcon.color, AppTheme.lightTheme.colorScheme.onSurface);
    },
  );

  testWidgets(
    'OccurrenceCard exibe no maximo 2 indicadores no topo e adapta cor no modo escuro',
    (WidgetTester tester) async {
      const ocorrencia = OcorrenciaModel(
        id: 1,
        usuarioId: 2,
        titulo: 'Elevador travado na estação',
        descricao: 'Plataforma elevatória não responde ao comando.',
        tipo: TipoOcorrencia.ELEVADOR_INOPERANTE,
        gravidade: NivelGravidade.ALTA,
        status: StatusOcorrencia.ABERTA,
        afetaAcessibilidade: true,
        codigoLinha: 2506,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: OccurrenceCard(ocorrencia: ocorrencia)),
        ),
      );

      expect(find.text('Elevador PcD Inoperante'), findsOneWidget);
      expect(find.text('PcD • Alta'), findsOneWidget);
      expect(find.text('Impacto PcD'), findsNothing);
      expect(find.text('Gravidade: Alta'), findsNothing);
    },
  );

  testWidgets(
    'OccurrenceDetailScreen remove # e jargoes tecnicos e formata data pt-BR',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const ocorrencia = OcorrenciaModel(
        id: 7,
        usuarioId: 2,
        titulo: 'Rampa com defeito',
        descricao: 'Rampa manual presa.',
        tipo: TipoOcorrencia.ACESSIBILIDADE,
        gravidade: NivelGravidade.ALTA,
        status: StatusOcorrencia.ABERTA,
        afetaAcessibilidade: true,
        codigoLinha: 2506,
        codigoParada: 340015329,
        criadoEm: '2026-11-18T14:30:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: const RouteSettings(arguments: ocorrencia),
              builder: (_) => const OccurrenceDetailScreen(),
            );
          },
        ),
      );

      expect(find.text('Detalhes do Relato'), findsOneWidget);
      expect(find.text('Ocorrência #7'), findsNothing);
      expect(find.text('Ver Ônibus desta Linha no Mapa'), findsOneWidget);
      expect(find.textContaining('2506'), findsOneWidget);
      expect(find.textContaining('(cl)'), findsNothing);
      expect(find.textContaining('(cp)'), findsNothing);
      expect(find.text('18/11/2026 às 14:30'), findsOneWidget);
    },
  );
}
