import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/services/sheets_service.dart';
import 'core/services/notification_service.dart';
import 'data/local/hive_cache.dart';
import 'data/repositories/tourist_repository.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'background/workmanager_dispatcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Run App
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // A. Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // B. Initialize Hive local cache and register TypeAdapters
    await HiveCache.init();

    // Clear the old default hardcoded sheet ID if present
    if (HiveCache.getSpreadsheetId() ==
        '1tuGfsQj-Pp9ldd3NjG8MmkuRA85azzZfdYNQV8YBAhY') {
      await HiveCache.setSpreadsheetId(null);
    }

    // C. Initialize Local Notifications Plugin
    await NotificationService.init();

    // D. Initialize Google Sheets
    final sheetsService = SheetsService();
    await sheetsService.init();

    final todayStr = _getTodayFormatted();
    final activeDate = HiveCache.getCurrentDate(todayStr);

    // Write today's default if not set
    await HiveCache.setCurrentDate(activeDate);

    // E. Perform Sheets synchronization in the background (NON-blocking!)
    _syncSheetsInBackground(activeDate);

    // F. If administrator, initialize Workmanager and launch periodic task
    const storage = FlutterSecureStorage();
    final isAdmin = await storage.read(key: 'isAdmin') == 'true';
    if (isAdmin) {
      print('Admin mode verified. Initializing Workmanager.');
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'flight-poll',
        'flightPollTask',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  Future<void> _syncSheetsInBackground(String activeDate) async {
    try {
      await TouristRepository.loadAndSyncFromSheets(activeDate);
      print('Initial data sync from Google Sheets succeeded.');
    } catch (e) {
      print('Initial Sheets sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usherer',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.accent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Initialization Failed',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: AppTypography.bodySecondary,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return const DashboardScreen();
        },
      ),
    );
  }
}

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
