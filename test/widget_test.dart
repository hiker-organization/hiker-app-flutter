// Teste de widget básico do Flutter.
//
// Para interagir com um widget no teste, use o WidgetTester do pacote
// flutter_test. Com ele dá para enviar toques e rolagens, encontrar widgets
// filhos na árvore, ler textos e conferir os valores das propriedades.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_hiker/app_module.dart';
import 'package:app_hiker/main.dart';

void main() {
  testWidgets('a tela de login mostra o formulário de login', (WidgetTester tester) async {
    // O AuthGateScreen lê a sessão salva primeiro; sem tokens, vai para /login.
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(ModularApp(module: AppModule(), child: const AppWidget()));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
