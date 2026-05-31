import 'package:flutter/foundation.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/sheets_service.dart';
import '../../core/services/flight_api_service.dart';
import '../../core/services/notification_service.dart';
import '../models/tourist_group.dart';
import '../models/flight.dart';

class FlightRepository {
  static final FirestoreService _firestoreService = FirestoreService();
  static final SheetsService _sheetsService = SheetsService();
  static final FlightApiService _flightApiService = FlightApiService();

  // Tracks which flight numbers are currently being actively polled
  static final ValueNotifier<Set<String>> pollingFlights =
      ValueNotifier<Set<String>>({});

  // Executed by Admin Workmanager background task or foreground on-demand poll
  static Future<void> pollFlights(
    String date,
    List<TouristGroup> groups,
  ) async {
    if (groups.isEmpty) return;

    // Parse target month and day from date string (e.g. "22ND MAY")
    int? targetMonth;
    int? targetDay;
    try {
      final cleanStr = date.trim().toUpperCase();
      final parts = cleanStr.split(' ');
      if (parts.length >= 2) {
        final dayStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
        targetDay = int.tryParse(dayStr);

        final monthNames = [
          'JAN',
          'FEB',
          'MAR',
          'APR',
          'MAY',
          'JUN',
          'JUL',
          'AUG',
          'SEP',
          'OCT',
          'NOV',
          'DEC',
        ];
        final monthStr = parts[1];
        final idx = monthNames.indexWhere((m) => monthStr.startsWith(m));
        if (idx != -1) {
          targetMonth = idx + 1;
        }
      }
    } catch (_) {}

    // Grouping by flight number to avoid duplicate API requests
    final Map<String, List<TouristGroup>> flightToGroups = {};
    for (final group in groups) {
      if (group.flightNumber.isNotEmpty) {
        flightToGroups.putIfAbsent(group.flightNumber, () => []).add(group);
      }
    }

    final Set<String> flightsToPoll = flightToGroups.keys
        .where((f) => f != 'No Flight')
        .toSet();

    // Add all flights in this batch to the active polling set
    pollingFlights.value = {...pollingFlights.value, ...flightsToPoll};

    try {
      for (final entry in flightToGroups.entries) {
        final flightNumber = entry.key;
        if (flightNumber == 'No Flight') continue;
        final matchingGroups = entry.value;

        // Add a 4 second delay between requests to respect the rate limit (1 request/sec, max 180/hr) of BASIC plan
        await Future.delayed(const Duration(seconds: 4));

        try {
          final flightData = await _flightApiService.fetchFlight(
            flightNumber,
            targetMonth: targetMonth,
            targetDay: targetDay,
          );

          // Remove this flight from the active polling list immediately once fetched
          pollingFlights.value = pollingFlights.value
              .where((f) => f != flightNumber)
              .toSet();

          if (flightData == null) continue;

          bool hasNotifiedForThisFlight = false;

          for (final group in matchingGroups) {
            // Overwrite bug guard:
            // Do not overwrite an existing valid ETA (non-null, non-empty, non-"No ETA") with "No ETA"
            final targetEta =
                (flightData.eta == 'No ETA' &&
                    group.liveEta != null &&
                    group.liveEta!.isNotEmpty &&
                    group.liveEta != 'No ETA')
                ? group.liveEta!
                : flightData.eta;

            final calculatedStatus = (flightData.status == FlightStatus.arrived)
                ? FlightStatus.arrived
                : FlightStatusExtension.calculateStatus(
                    scheduledTime: group.scheduledTime,
                    liveEtaStr: targetEta,
                  );

            final normGroupEta = FlightStatusExtension.normalizeTimeStr(group.liveEta);
            final normTargetEta = FlightStatusExtension.normalizeTimeStr(targetEta);
            final isEtaChanged = normGroupEta != normTargetEta;

            // If live ETA or status has changed, update
            if (isEtaChanged || group.flightStatus != calculatedStatus) {
              // 1. Update Firestore (live state)
              await _firestoreService.updateGroupEta(
                date: date,
                groupId: group.id,
                liveEta: targetEta,
                status: calculatedStatus,
              );

              // 2. Update Sheets ONLY if the actual ETA value changed (saves quota & prevents loop overwrites)
              if (isEtaChanged && group.sheetRow != null) {
                await _sheetsService.writeEta(date, group.sheetRow!, targetEta);
              }

              // 3. Trigger alert notification ONLY on actual liveEta flight time change from a previous valid ETA
              if (normGroupEta != null &&
                  normTargetEta != null &&
                  isEtaChanged &&
                  !hasNotifiedForThisFlight) {
                hasNotifiedForThisFlight = true;
                await NotificationService.showNotification(
                  id: flightNumber.hashCode,
                  title: 'Flight $flightNumber Status Update',
                  body: 'New ETA is $targetEta',
                );
              }
            }
          }
        } catch (e) {
          print('Error polling flight $flightNumber: $e');
        }
      }
    } finally {
      pollingFlights.value = pollingFlights.value.difference(flightsToPoll);
    }
  }
}
