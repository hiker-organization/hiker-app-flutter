import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Acceptance of the privacy policy at sign-up. The link opens the policy, and the rest of
// the text toggles the box.
class PrivacyPolicyCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const PrivacyPolicyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    void toggle() {
      if (enabled) onChanged(!value);
    }

    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
            activeColor: Pallete.primaryColor,
            checkColor: Pallete.textDarkColor,
            side: BorderSide(color: Pallete.whiteColor.withAlpha(180), width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              GestureDetector(
                onTap: toggle,
                child: const Text('Li e aceito a ', style: TextStyle(fontSize: 15, color: Pallete.whiteColor)),
              ),
              GestureDetector(
                onTap: () => context.pushNamed('/privacy-policy'),
                child: const Text(
                  'Política de Privacidade',
                  style: TextStyle(
                    fontSize: 15,
                    color: Pallete.primaryColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Pallete.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
