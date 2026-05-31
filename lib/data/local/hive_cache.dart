import 'package:hive_flutter/hive_flutter.dart';
import '../models/tourist_group.dart';
import '../models/tourist.dart';
import '../models/flight.dart';

class HiveCache {
  static late Box<TouristGroup> groupsBox;
  static late Box<dynamic> settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters with specific typeIds
    Hive.registerAdapter(FlightStatusAdapter()); // typeId: 2
    Hive.registerAdapter(TouristAdapter()); // typeId: 1
    Hive.registerAdapter(TouristGroupAdapter()); // typeId: 0

    groupsBox = await Hive.openBox<TouristGroup>('groups');
    settingsBox = await Hive.openBox<dynamic>('settings');
  }

  static List<TouristGroup> getCachedGroups() {
    return groupsBox.values.toList();
  }

  static Future<void> cacheGroups(List<TouristGroup> groups) async {
    await groupsBox.clear();
    final groupMap = {for (var group in groups) group.id: group};
    await groupsBox.putAll(groupMap);
  }

  static Future<void> cacheSingleGroup(TouristGroup group) async {
    await groupsBox.put(group.id, group);
  }

  static String getCurrentDate(String defaultVal) {
    return settingsBox.get('currentDate', defaultValue: defaultVal) as String;
  }

  static Future<void> setCurrentDate(String date) async {
    await settingsBox.put('currentDate', date);
  }

  static bool getNotificationsEnabled() {
    return settingsBox.get('notificationsEnabled', defaultValue: true) as bool;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await settingsBox.put('notificationsEnabled', enabled);
  }

  static String? getSpreadsheetId() {
    return settingsBox.get('spreadsheetId') as String?;
  }

  static Future<void> setSpreadsheetId(String? id) async {
    if (id == null) {
      await settingsBox.delete('spreadsheetId');
    } else {
      await settingsBox.put('spreadsheetId', id);
    }
  }

  static Map<String, dynamic> getApiKeyQuotas() {
    final dynamic stored = settingsBox.get('apiKeyQuotas');
    if (stored is Map) {
      return Map<String, dynamic>.from(stored);
    }
    return <String, dynamic>{};
  }

  static Future<void> setApiKeyQuotas(Map<String, dynamic> quotas) async {
    await settingsBox.put('apiKeyQuotas', quotas);
  }
}
