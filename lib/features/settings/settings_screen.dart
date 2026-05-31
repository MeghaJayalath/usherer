import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../settings/admin_unlock_dialog.dart';
import '../../data/local/hive_cache.dart';
import '../../core/services/firestore_service.dart';
import '../../data/repositories/tourist_repository.dart';
import '../../app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isAdmin = false;
  final _storage = const FlutterSecureStorage();
  final _firestoreService = FirestoreService();

  // Easter Egg variables
  int _tapCount = 0;
  DateTime? _firstTapTime;

  // Sheet ID
  final TextEditingController _sheetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = HiveCache.getNotificationsEnabled();
    _checkAdminStatus();
    _loadSheetId();
    _sheetIdController.addListener(_onSheetIdChanged);
  }

  @override
  void dispose() {
    _sheetIdController.removeListener(_onSheetIdChanged);
    _sheetIdController.dispose();
    super.dispose();
  }

  void _onSheetIdChanged() {
    setState(() {});
  }

  Future<void> _checkAdminStatus() async {
    final status = await _storage.read(key: 'isAdmin') == 'true';
    setState(() {
      _isAdmin = status;
    });
  }

  void _loadSheetId() {
    final currentId = HiveCache.getSpreadsheetId() ?? '';
    _sheetIdController.text = currentId;
  }

  String _extractSpreadsheetId(String input) {
    final clean = input.trim();
    if (clean.contains('/d/')) {
      final regExp = RegExp(r'/d/([a-zA-Z0-9-_]+)');
      final match = regExp.firstMatch(clean);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
    }
    return clean;
  }

  bool _isSyncing = false;

  String _getTodayFormatted() {
    final now = DateTime.now();
    final monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUNE',
      'JULY',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final monthStr = monthNames[now.month - 1];

    String suffix = 'TH';
    final day = now.day;
    if (day >= 11 && day <= 13) {
      suffix = 'TH';
    } else {
      switch (day % 10) {
        case 1:
          suffix = 'ST';
          break;
        case 2:
          suffix = 'ND';
          break;
        case 3:
          suffix = 'RD';
          break;
        default:
          suffix = 'TH';
          break;
      }
    }
    return '$day$suffix $monthStr';
  }

  Future<void> _saveSheetId() async {
    // 1. Automatically unfocus the text field
    FocusScope.of(context).unfocus();

    final rawInput = _sheetIdController.text.trim();
    if (rawInput.isEmpty) {
      await HiveCache.setSpreadsheetId(null);
      await _firestoreService.setRemoteSpreadsheetId(null);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sheet ID cleared successfully.'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
      return;
    }

    final cleanId = _extractSpreadsheetId(rawInput);

    // Update the controller so the user visually sees the extracted clean ID
    _sheetIdController.text = cleanId;

    await HiveCache.setSpreadsheetId(cleanId);
    await _firestoreService.setRemoteSpreadsheetId(cleanId);

    setState(() {
      _isSyncing = true;
    });

    try {
      final activeDate = HiveCache.getCurrentDate(_getTodayFormatted());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sheet ID saved. Synchronizing data for $activeDate...',
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await TouristRepository.loadAndSyncFromSheets(activeDate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data synced successfully!'),
            backgroundColor: AppColors.early,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-sync failed: $e'),
            backgroundColor: AppColors.early,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_firstTapTime == null ||
        now.difference(_firstTapTime!) > const Duration(seconds: 3)) {
      _tapCount = 1;
      _firstTapTime = now;
    } else {
      _tapCount++;
    }

    if (_tapCount >= 5) {
      _tapCount = 0;
      _firstTapTime = null;
      if (_isAdmin) {
        _showKillSwitchConfirm();
      } else {
        _showAdminUnlock();
      }
    }
  }

  Future<void> _showKillSwitchConfirm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceHigh,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SYSTEM KILL SWITCH',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This will instantly wipe all operational data from Firestore for the current date session, clear the local cache, and remove the connected Google Sheet URL.',
                style: AppTypography.bodySecondary.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'NOTE: This does NOT delete data from the actual Google Spreadsheet file. It only clears the app\'s live database.',
                style: AppTypography.bodySecondary.copyWith(
                  height: 1.5,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
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
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Wipe Data', style: AppTypography.buttonText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await TouristRepository.wipeAllData();

        // Also deactivate admin mode
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'isAdmin');

        setState(() {
          _sheetIdController.clear();
          _isAdmin = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'All data wiped successfully. Admin mode deactivated.',
              ),
              backgroundColor: AppColors.early,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to wipe data: $e'),
              backgroundColor: AppColors.early,
            ),
          );
        }
      }
    }
  }

  Future<void> _showAdminUnlock() async {
    if (_isAdmin) return;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdminUnlockDialog(),
    );

    if (success == true) {
      setState(() {
        _isAdmin = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin mode enabled successfully'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'SETTINGS',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        // Settings group
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: SwitchListTile(
                                  secondary: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppColors.accent,
                                  ),
                                  title: Text(
                                    'Push Notifications',
                                    style: AppTypography.bodyPrimary,
                                  ),
                                  subtitle: Text(
                                    'Receive alerts on flight ETA delays',
                                    style: AppTypography.bodySecondary,
                                  ),
                                  activeColor: AppColors.accent,
                                  activeTrackColor: AppColors.accentMuted,
                                  inactiveThumbColor: AppColors.textSecondary,
                                  inactiveTrackColor: AppColors.border,
                                  value: _notificationsEnabled,
                                  onChanged: (val) async {
                                    setState(() {
                                      _notificationsEnabled = val;
                                    });
                                    await HiveCache.setNotificationsEnabled(
                                      val,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Google Sheet URL or ID Input (Admin only)
                        if (_isAdmin) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.table_chart_outlined,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'GOOGLE SHEET INTEGRATION',
                                            style: AppTypography.labelChip
                                                .copyWith(
                                                  color: AppColors.accent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Paste your Google Sheet link or ID to sync data.',
                                            style: AppTypography.bodySecondary
                                                .copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _sheetIdController,
                                        style: AppTypography.bodyPrimary
                                            .copyWith(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Paste the spreadsheet URL or ID here',
                                          hintStyle: AppTypography.bodySecondary
                                              .copyWith(fontSize: 13),
                                          filled: true,
                                          fillColor: AppColors.background,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.accent,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Builder(
                                      builder: (context) {
                                        final savedId =
                                            HiveCache.getSpreadsheetId() ?? '';
                                        final currentInput = _sheetIdController
                                            .text
                                            .trim();
                                        final parsedInput =
                                            _extractSpreadsheetId(currentInput);
                                        final isSaveDisabled =
                                            parsedInput == savedId ||
                                            _isSyncing;

                                        return SizedBox(
                                          height: 46,
                                          child: ElevatedButton(
                                            onPressed: isSaveDisabled
                                                ? null
                                                : _saveSheetId,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.accent,
                                              disabledBackgroundColor:
                                                  AppColors.background,
                                              disabledForegroundColor: AppColors
                                                  .textSecondary
                                                  .withValues(alpha: 0.5),
                                              foregroundColor:
                                                  AppColors.textPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                side: isSaveDisabled
                                                    ? const BorderSide(
                                                        color: AppColors.border,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                            ),
                                            child: _isSyncing
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(AppColors.accent),
                                                    ),
                                                  )
                                                : Text(
                                                    isSaveDisabled
                                                        ? 'SAVED'
                                                        : 'SAVE',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Paste the entire spreadsheet link or just the ID itself.',
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // AeroDataBox API Key status (Admin only)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.vpn_key_outlined,
                                      color: AppColors.vipGold,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'FLIGHT API KEY STATUS',
                                            style: AppTypography.labelChip
                                                .copyWith(
                                                  color: AppColors.vipGold,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'RapidAPI AeroDataBox remaining free requests.',
                                            style: AppTypography.bodySecondary
                                                .copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                                const SizedBox(height: 16),
                                ...AppConfig.flightApiKeys.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final key = entry.value;
                                  final quotas = HiveCache.getApiKeyQuotas();
                                  final quota = quotas[key] as Map?;

                                  final remaining = quota?['remaining'] as int?;
                                  final limit = quota?['limit'] as int?;

                                  final String displayKey = key.length > 12
                                      ? '${key.substring(0, 6)}...${key.substring(key.length - 6)}'
                                      : key;

                                  final percent = (limit != null && limit > 0 && remaining != null)
                                      ? (remaining / limit)
                                      : 1.0;

                                  Color progressColor = AppColors.arrived; // Green for healthy
                                  if (percent < 0.2) {
                                    progressColor = AppColors.accent; // Coral/Red for critical
                                  } else if (percent < 0.5) {
                                    progressColor = AppColors.vipGold; // Yellow for warning
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Key #${idx + 1} ($displayKey)',
                                              style: AppTypography.bodyPrimary.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              remaining != null && limit != null
                                                  ? '$remaining / $limit left'
                                                  : 'Pending first request...',
                                              style: AppTypography.bodySecondary.copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: remaining != null && limit != null
                                                    ? progressColor
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor: AppColors.border,
                                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Admin features (if enabled)
                        if (_isAdmin) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.accentMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.offline_bolt_outlined,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ADMIN MODE ACTIVE',
                                        style: AppTypography.labelChip.copyWith(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Background flight polling is running every 15 minutes.',
                                        style: AppTypography.bodySecondary
                                            .copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                    ],
                  ),
                ),
              ),

              // Fixed version info block (hidden when keyboard is open for better space utility)
              if (!isKeyboardOpen)
                GestureDetector(
                  onTap: _handleVersionTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icon.png',
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'USHERER v1.0.0',
                          style: AppTypography.bodyPrimary.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Powered by Google Sheets & Firestore',
                          style: AppTypography.bodySecondary.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
