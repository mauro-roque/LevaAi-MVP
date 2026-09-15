import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leva_ai/mvp/api.dart';
import 'package:leva_ai/mvp/app.dart';
import 'package:leva_ai/mvp/request_page.dart';
import 'package:leva_ai/mvp/ui.dart';

void main() {
  testWidgets('login responde a falha da API sem perder o formulário', (
    tester,
  ) async {
    final api = Api(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/config')) {
          return http.Response(jsonEncode({'demo': true}), 200);
        }
        return http.Response(
          jsonEncode({'error': 'E-mail ou senha incorretos.'}),
          401,
        );
      }),
    );
    await tester.pumpWidget(LevaAiMvp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'teste@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'errada',
    );
    await tester.tap(find.text('Entrar na minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Entrar na minha conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('informa quando o serviço está sendo ativado', (tester) async {
    final api = Api(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Configuração do banco pendente.'}),
          503,
        ),
      ),
    );
    await tester.pumpWidget(LevaAiMvp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Estamos preparando sua conexão segura.'), findsOneWidget);
    expect(find.text('Verificar novamente'), findsOneWidget);
    api.dispose();
  });

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('solicitação e login sem overflow em ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = Api(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: AuthPage(api: api, demo: true, onAuthenticated: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: RequestPage(
                api: api,
                config: const {'demo': false},
                onBooked: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Encontrar prestadores'));
      await tester.tap(find.text('Encontrar prestadores'));
      await tester.pumpAndSettle();
      expect(
        find.text('Descreva os itens e suas quantidades.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      api.dispose();
    });
  }
}
