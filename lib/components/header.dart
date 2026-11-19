import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final VoidCallback onNovaAvaliacaoTap;
  final VoidCallback onMenuTap;

  const Header({super.key, required this.onNovaAvaliacaoTap, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Pallete.whiteColor),
              onPressed: onNovaAvaliacaoTap,
            ),
            Image.asset('assets/img/logo.png', height: 32),
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu, color: Pallete.whiteColor),
              onPressed: onMenuTap,
            ),
          ],
        ),
      ),
    );
  }
}
