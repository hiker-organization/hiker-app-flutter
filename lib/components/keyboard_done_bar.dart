import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// iOS keyboards have no key to close them (the number one and the multiline text one
// don't even turn the return key into "Done"), so a bar with a "Done" button sits above
// the keyboard in every screen. Wraps the whole app, in MaterialApp.builder.
class KeyboardDoneBar extends StatelessWidget {
  static const height = 44.0;

  final Widget child;

  const KeyboardDoneBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Android keyboards already have their own key to close them.
    if (defaultTargetPlatform != TargetPlatform.iOS) return child;

    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    if (keyboardHeight <= 0) return child;

    return Stack(
      children: [
        // The bar counts as part of the keyboard, so the screens shrink and scroll the
        // focused field above it instead of leaving it under the bar.
        MediaQuery(
          data: mediaQuery.copyWith(
            viewInsets: mediaQuery.viewInsets.copyWith(bottom: keyboardHeight + height),
          ),
          child: child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: keyboardHeight,
          child: Material(
            color: Pallete.surfaceColor,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Pallete.whiteColor.withAlpha(25))),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                icon: const Icon(Icons.check_rounded, color: Pallete.primaryColor),
                label: const Text(
                  'Concluído',
                  style: TextStyle(color: Pallete.primaryColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
