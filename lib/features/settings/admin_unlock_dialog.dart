import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:workmanager/workmanager.dart';
import '../../../app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../background/workmanager_dispatcher.dart';

class AdminUnlockDialog extends StatefulWidget {
  const AdminUnlockDialog({super.key});

  @override
  State<AdminUnlockDialog> createState() => _AdminUnlockDialogState();
}

class _AdminUnlockDialogState extends State<AdminUnlockDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _attemptUnlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Direct bcrypt verification
      final isCorrect = BCrypt.checkpw(password, AppConfig.adminPasswordHash);

      if (isCorrect) {
        // 1. Persist admin flag securely
        await _storage.write(key: 'isAdmin', value: 'true');

        // 2. Initialize and Register Workmanager task
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: false,
        );
        await Workmanager().registerPeriodicTask(
          'flight-poll',
          'flightPollTask',
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect administrator password';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred during verification';
        _isLoading = false;
      });
      print('AdminUnlockDialog verification exception: $e');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.accent,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'Administrator Access',
              style: AppTypography.titleMedium.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter password to enable background flight sync and notification polling features.',
              style: AppTypography.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: AppTypography.bodyPrimary,
              decoration: InputDecoration(
                hintText: 'Enter Admin Password',
                errorText: _errorMessage,
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                ),
              ),
              onSubmitted: (_) => _isLoading ? null : _attemptUnlock(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: AppTypography.buttonText.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _attemptUnlock,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.textPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Unlock', style: AppTypography.buttonText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
