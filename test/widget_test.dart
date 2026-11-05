// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_hiker/app_module.dart';
import 'package:app_hiker/main.dart';

void main() {
  testWidgets('Login screen shows the login form', (WidgetTester tester) async {
    // AuthGateScreen reads the stored session first; with no tokens it goes to /login.
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(ModularApp(module: AppModule(), child: const AppWidget()));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
