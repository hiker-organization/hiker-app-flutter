import 'package:app_hiker/components/keyboard_done_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// keyboardHeight simulates the open keyboard through the MediaQuery insets.
Widget _app({required double keyboardHeight, required FocusNode focusNode}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      viewInsets: EdgeInsets.only(bottom: keyboardHeight),
    ),
    child: MaterialApp(
      builder: (context, child) => KeyboardDoneBar(child: child!),
      home: Scaffold(body: TextField(focusNode: focusNode)),
    ),
  );
}

void main() {
  testWidgets('no iOS com o teclado aberto, "Concluído" fecha o teclado', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(_app(keyboardHeight: 300, focusNode: focusNode));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Concluído'));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    focusNode.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a barra não aparece sem teclado aberto', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(_app(keyboardHeight: 0, focusNode: focusNode));

    expect(find.text('Concluído'), findsNothing);
    focusNode.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a barra não aparece no Android, que tem a própria tecla de fechar', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(_app(keyboardHeight: 300, focusNode: focusNode));

    expect(find.text('Concluído'), findsNothing);
    focusNode.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
