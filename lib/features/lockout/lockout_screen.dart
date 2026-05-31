import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class LockoutScreen extends StatelessWidget {
  const LockoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.block_flipped,
                color: AppColors.accent,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'This app has expired.',
                style: AppTypography.displayHeader.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The trial period for Usherer has concluded. Please contact the administrator for updates or support.',
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
