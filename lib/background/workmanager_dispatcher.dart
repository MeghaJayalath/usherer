import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import '../app_config.dart';
import '../data/local/hive_cache.dart';
import '../data/repositories/flight_repository.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, data) async {
    try {
      print('Workmanager Task: Background sync execution started. Task: $task');

      // 1. Initialize Hive Local DB inside this background thread isolate
      await HiveCache.init();

      // 2. Fetch current configurations
      final date = HiveCache.settingsBox.get('currentDate') as String?;
      final groups = HiveCache.getCachedGroups();

      if (date == null || groups.isEmpty) {
        print(
          'Workmanager Task: Finished. No active date or cached groups to sync.',
        );
        return true;
      }

      // 3. Initialize Firebase inside this background thread isolate
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 4. Poll live flights using flight repository
      await FlightRepository.pollFlights(date, groups);

      print('Workmanager Task: Background flight sync completed successfully.');
      return true;
    } catch (e) {
      print('Workmanager Task: Background execution exception: $e');
      return false; // Tells Workmanager the task failed and should be retried later
    }
  });
}
