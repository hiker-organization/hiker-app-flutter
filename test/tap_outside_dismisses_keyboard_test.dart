import 'package:app_hiker/components/tap_outside_dismisses_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required FocusNode focusNode, VoidCallback? onButton}) {
  return MaterialApp(
    builder: (context, child) => TapOutsideDismissesKeyboard(child: child!),
    home: Scaffold(
      body: Column(
        children: [
          TextField(key: const Key('a'), focusNode: focusNode),
          const TextField(key: Key('b')),
          ElevatedButton(onPressed: onButton ?? () {}, child: const Text('Botão')),
          const Expanded(child: SizedBox.expand(key: Key('vazio'))),
        ],
      ),
    ),
  );
}

void main() {
  final variant = TargetPlatformVariant.mobile();

  testWidgets('tocar numa área vazia fecha o teclado', (tester) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(_app(focusNode: focusNode));
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('vazio')));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    focusNode.dispose();
  }, variant: variant);

  testWidgets('tocar num botão fecha o teclado e ainda aciona o botão', (tester) async {
    final focusNode = FocusNode();
    var pressed = false;
    await tester.pumpWidget(_app(focusNode: focusNode, onButton: () => pressed = true));
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();

    await tester.tap(find.text('Botão'));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(pressed, isTrue);
    focusNode.dispose();
  }, variant: variant);

  testWidgets('tocar em outro campo passa o foco pra ele', (tester) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(_app(focusNode: focusNode));
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('b')));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    focusNode.dispose();
  }, variant: variant);
}
