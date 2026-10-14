import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SocialButton extends StatelessWidget {
  final String iconName;
  final String label;
  final double horizontalPadding;
  final VoidCallback onPressed;
  // Disables the button and shows a spinner in place of the icon.
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.iconName,
    required this.label,
    this.horizontalPadding = 80,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2, color: Pallete.whiteColor),
              ),
            )
          : SvgPicture.asset(
              'assets/svg/$iconName.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Pallete.whiteColor,
                BlendMode.srcIn,
              ),
            ),
      label: Text(
        label,
        style: const TextStyle(color: Pallete.whiteColor)
      ),
      style: TextButton.styleFrom(
        backgroundColor: Pallete.backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Pallete.borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
      )
    );
  }
}
