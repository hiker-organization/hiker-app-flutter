import 'package:flutter/material.dart';

// Flutter has no native "Done" bar above the iOS keyboard, and by default on phones a
// touch outside a text field keeps it focused, so the keyboard never closes. This makes
// a touch anywhere outside the text fields close the keyboard, in every screen. Touching
// another text field isn't outside: all of them share the same tap region group.
// Wraps the whole app, in MaterialApp.builder.
class TapOutsideDismissesKeyboard extends StatelessWidget {
  final Widget child;

  const TapOutsideDismissesKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            intent.focusNode.unfocus();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}
