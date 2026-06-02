import 'package:flutter/material.dart';
import '../../data/local/hive_cache.dart';
import 'app_colors.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void init() {
    final savedMode = HiveCache.getThemeMode();
    themeModeNotifier.value = _parseThemeMode(savedMode);
    _updateAppColors(themeModeNotifier.value);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await HiveCache.setThemeMode(mode.name);
    _updateAppColors(mode);
  }

  static void handleSystemBrightnessChange(Brightness brightness) {
    if (themeModeNotifier.value == ThemeMode.system) {
      AppColors.updateTheme(brightness == Brightness.dark);
    }
  }

  static void _updateAppColors(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      AppColors.updateTheme(brightness == Brightness.dark);
    } else {
      AppColors.updateTheme(mode == ThemeMode.dark);
    }
  }

  static ThemeMode _parseThemeMode(String modeStr) {
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
