import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../../app_config.dart';
import '../../data/models/tourist_group.dart';
import '../../data/models/tourist.dart';
import '../../data/models/flight.dart';
import '../../data/local/hive_cache.dart';

class SheetsService {
  // Singleton pattern for globally shared credentials instance
  static final SheetsService _instance = SheetsService._internal();
  factory SheetsService() => _instance;
  SheetsService._internal();

  sheets.SheetsApi? _sheetsApi;

  // Cache of resolved sheet tab names: key is rawDateName, value is sheetsActualTabName
  static final Map<String, String> _resolvedTabNames = {};

  // Ensure authenticated client is present before making requests (background isolate resilient)
  Future<void> _ensureInitialized() async {
    if (_sheetsApi != null) return;

    final cachedJson =
        HiveCache.settingsBox.get('serviceAccountJson') as String?;
    if (cachedJson != null) {
      await initWithCredentialsString(cachedJson);
    } else {
      throw Exception(
        'SheetsService has not been initialized with service account credentials yet.',
      );
    }
  }

  // Initialize service account in foreground using assets
  Future<void> init() async {
    try {
      final credentialsJson = await rootBundle.loadString(
        AppConfig.serviceAccountAssetPath,
      );

      // Cache in Hive settings for background isolate use
      await HiveCache.settingsBox.put('serviceAccountJson', credentialsJson);

      await initWithCredentialsString(credentialsJson);
    } catch (e) {
      print('SheetsService init error: $e');
    }
  }

  // Initialize service account using direct JSON credentials string (safe for background isolates)
  Future<void> initWithCredentialsString(String credentialsJsonString) async {
    final credentialsMap =
        jsonDecode(credentialsJsonString) as Map<String, dynamic>;
    final accountCredentials = ServiceAccountCredentials.fromJson(
      credentialsMap,
    );

    final client = await clientViaServiceAccount(accountCredentials, [
      sheets.SheetsApi.spreadsheetsScope,
    ]);

    _sheetsApi = sheets.SheetsApi(client);
  }

  // Resolves the actual Google Sheet tab name by looking up titles and performing fuzzy/abbreviation matching
  Future<String> _resolveSheetTabName(String rawName) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return rawName;

    // Check memory cache first
    if (_resolvedTabNames.containsKey(rawName)) {
      return _resolvedTabNames[rawName]!;
    }

    await _ensureInitialized();

    try {
      final spreadsheet = await _sheetsApi!.spreadsheets.get(sheetId);
      final titles =
          spreadsheet.sheets
              ?.map((s) => s.properties?.title)
              .whereType<String>()
              .toList() ??
          [];

      if (titles.isNotEmpty) {
        final matched = _findBestTabMatch(rawName, titles);
        if (matched != null) {
          _resolvedTabNames[rawName] = matched;
          return matched;
        }
      }
    } catch (e) {
      print('Error resolving sheet tab name: $e');
    }

    // Default to rawName if we can't find a match or request fails
    return rawName;
  }

  // Performs case-insensitive, spacing-resilient, and abbreviated month matches (e.g. JUN -> JUNE)
  String? _findBestTabMatch(String target, List<String> available) {
    final cleanTarget = target.trim().toUpperCase().replaceAll(' ', '');

    // 1. Exact case-insensitive / spacing mismatch
    for (final title in available) {
      final cleanTitle = title.trim().toUpperCase().replaceAll(' ', '');
      if (cleanTitle == cleanTarget) {
        return title;
      }
    }

    // 2. Abbreviated match (e.g., target is '1ST JUNE' and sheet is '1ST JUN')
    String targetAlt = cleanTarget;
    if (cleanTarget.contains('JUNE')) {
      targetAlt = cleanTarget.replaceAll('JUNE', 'JUN');
    } else if (cleanTarget.contains('JULY')) {
      targetAlt = cleanTarget.replaceAll('JULY', 'JUL');
    } else if (cleanTarget.contains('SEPTEMBER')) {
      targetAlt = cleanTarget.replaceAll('SEPTEMBER', 'SEP');
    }

    for (final title in available) {
      final cleanTitle = title.trim().toUpperCase().replaceAll(' ', '');
      String titleAlt = cleanTitle;
      if (cleanTitle.contains('JUNE')) {
        titleAlt = cleanTitle.replaceAll('JUNE', 'JUN');
      } else if (cleanTitle.contains('JULY')) {
        titleAlt = cleanTitle.replaceAll('JULY', 'JUL');
      } else if (cleanTitle.contains('SEPTEMBER')) {
        titleAlt = cleanTitle.replaceAll('SEPTEMBER', 'SEP');
      }

      if (titleAlt == targetAlt) {
        return title;
      }
    }

    return null;
  }

  // Fetch groups and tourists from a specific Sheet tab
  Future<List<TouristGroup>> fetchSheetData(String sheetName) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) {
      print(
        'SheetsService: No spreadsheet ID configured. Returning empty data.',
      );
      return [];
    }

    final resolvedName = await _resolveSheetTabName(sheetName);

    await _ensureInitialized();

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        sheetId,
        "'$resolvedName'!A:O",
      );

      final rows = response.values;
      if (rows == null || rows.isEmpty) {
        return [];
      }

      List<TouristGroup> groups = [];

      String? currentVehicleType;
      String? currentNumberPlate;
      String? currentDriverContactInfo;
      int? currentSheetRow;
      DateTime? currentScheduledTime;
      String? currentLiveEta;
      List<Tourist> currentTourists = [];
      List<List<String>> currentTouristsFlights = [];

      void saveCurrentGroup() {
        if (currentVehicleType == null || currentTourists.isEmpty) return;

        // Count frequency of ALL flight numbers mentioned in this chunk
        final Map<String, int> flightCounts = {};
        for (final flights in currentTouristsFlights) {
          for (final f in flights) {
            flightCounts[f] = (flightCounts[f] ?? 0) + 1;
          }
        }

        String resolvedFlight = 'No Flight';

        if (flightCounts.isNotEmpty) {
          // Find the maximum frequency
          int maxCount = -1;
          flightCounts.forEach((flight, count) {
            if (count > maxCount) {
              maxCount = count;
            }
          });

          // Collect all flights that have this maximum frequency
          final candidates = flightCounts.entries
              .where((e) => e.value == maxCount)
              .map((e) => e.key)
              .toList();

          // Pick the first candidate
          if (candidates.isNotEmpty) {
            resolvedFlight = candidates.first;
          }
        }

        groups.add(
          TouristGroup(
            id: 'group_${currentSheetRow}_${currentVehicleType.replaceAll(' ', '_')}',
            vehicleType: currentVehicleType,
            vehicleLabel: currentVehicleType,
            scheduledTime: currentScheduledTime ?? DateTime.now(),
            flightNumber: resolvedFlight,
            liveEta: currentLiveEta,
            flightStatus: FlightStatusExtension.calculateStatus(
              scheduledTime: currentScheduledTime ?? DateTime.now(),
              liveEtaStr: currentLiveEta,
            ),
            tourists: List.from(currentTourists),
            sheetRow: currentSheetRow,
            numberPlate: currentNumberPlate,
            driverContactInfo: currentDriverContactInfo,
          ),
        );

        // Reset accumulators
        currentTourists.clear();
        currentTouristsFlights.clear();
      }

      // Start parsing from index 1 to skip header row
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowIndex =
            i +
            1; // 1-indexed row number in Sheets (row 1 is header, so index 1 is row 2)

        final String colA = row.isNotEmpty
            ? row[0].toString().trim()
            : ''; // pick_up
        final String colB = row.length > 1
            ? row[1].toString().trim()
            : ''; // drop_off
        final String colD = row.length > 3
            ? row[3].toString().trim()
            : ''; // vehicle_type
        final String colE = row.length > 4
            ? row[4].toString().trim()
            : ''; // number_plate
        final String colF = row.length > 5
            ? row[5].toString().trim()
            : ''; // driver_contact_info
        final String colG = row.length > 6
            ? row[6].toString().trim()
            : ''; // flight_number
        final String colH = row.length > 7
            ? row[7].toString().trim()
            : ''; // scheduled_time
        final String colI = row.length > 8
            ? row[8].toString().trim()
            : ''; // actual_time (live_eta)
        final String colJ = row.length > 9
            ? row[9].toString().trim()
            : ''; // tourist_name
        final String colK = row.length > 10
            ? row[10].toString().trim()
            : ''; // contact_info
        final String colL = row.length > 11
            ? row[11].toString().trim()
            : ''; // priority
        final String colM = row.length > 12
            ? row[12].toString().trim()
            : ''; // hotel
        final String colN = row.length > 13
            ? row[13].toString().trim()
            : ''; // hub
        final String colO = row.length > 14
            ? row[14].toString().trim()
            : ''; // notes

        // Skip header/metadata rows - column D would contain the header label, not a real vehicle type
        final colDLower = colD
            .toLowerCase()
            .replaceAll('_', '')
            .replaceAll(' ', '');
        final isHeaderRow =
            colDLower == 'vehicletype' ||
            colDLower == 'vehicle' ||
            colDLower == 'type' ||
            colDLower == 'sr' ||
            colDLower == 'sno' ||
            colDLower == 'slno';
        if (isHeaderRow) continue;

        // If Column D has a vehicle type, we save the previous group and start a new one
        if (colD.isNotEmpty) {
          saveCurrentGroup();
          currentVehicleType = _formatVehicleType(colD);
          currentNumberPlate = colE.isNotEmpty ? colE : null;
          currentDriverContactInfo = colF.isNotEmpty ? colF : null;
          currentSheetRow = rowIndex;
          currentScheduledTime = _parseTime(colH);
          currentLiveEta = _isValidTimeValue(colI) ? colI : null;
        } else {
          // Captures number plate or driver contact info if they reside on subsequent tourist rows in the sheet
          if (currentNumberPlate == null && colE.isNotEmpty) {
            currentNumberPlate = colE;
          }
          if (currentDriverContactInfo == null && colF.isNotEmpty) {
            currentDriverContactInfo = colF;
          }
        }

        // Add tourist if there is a name
        if (currentVehicleType != null && colJ.isNotEmpty) {
          final touristId = 'tourist_$rowIndex';
          final pickUpVal = colA.toLowerCase() == 'true';
          final dropOffVal = colB.toLowerCase() == 'true';

          currentTourists.add(
            Tourist(
              id: touristId,
              name: colJ,
              hasArrived: pickUpVal && dropOffVal,
              arrivedAt: (pickUpVal || dropOffVal)
                  ? DateTime.now().toIso8601String()
                  : null,
              markedBy: (pickUpVal || dropOffVal) ? 'Sheets Import' : null,
              sheetRow: rowIndex,
              pickUp: pickUpVal,
              dropOff: dropOffVal,
              priority: colL,
              hotel: colM,
              hub: colN,
              notes: colO,
              contactInfo: colK,
            ),
          );

          if (colG.isNotEmpty) {
            final normalized = _normalizeFlightNumber(colG);
            currentTouristsFlights.add([normalized]);
          } else {
            currentTouristsFlights.add([]);
          }
        }
      }

      // Save last group
      saveCurrentGroup();

      return groups;
    } catch (e) {
      print('fetchSheetData error: $e');
      if (e.toString().contains('Unable to parse range') ||
          e.toString().contains('Requested entity was not found')) {
        try {
          final spreadsheet = await _sheetsApi!.spreadsheets.get(sheetId);
          final titles =
              spreadsheet.sheets
                  ?.map((s) => s.properties?.title)
                  .whereType<String>()
                  .toList() ??
              [];
          if (titles.isNotEmpty) {
            throw Exception(
              "Tab '$sheetName' does not exist. Available tabs are: ${titles.join(', ')}",
            );
          }
        } catch (inner) {
          if (inner.toString().contains('does not exist')) {
            rethrow;
          }
        }
        throw Exception(
          "Tab '$sheetName' does not exist in your Google Sheet. Please check the spelling or create it.",
        );
      }
      rethrow;
    }
  }

  // Helper method to detect if a cell represents a flight number
  bool _isFlightNumber(String val) {
    String clean = val
        .trim()
        .replaceAll('|', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .toUpperCase();
    if (clean.startsWith('AL') &&
        clean.length > 2 &&
        RegExp(r'[0-9]').hasMatch(clean.substring(2))) {
      clean = 'AI${clean.substring(2)}';
    }
    if (clean.isEmpty) return false;
    // Flight numbers are between 3 and 8 chars, and contain at least one digit
    if (clean.length < 3 || clean.length > 8) return false;
    if (!clean.contains(RegExp(r'[0-9]'))) return false;
    if (int.tryParse(clean) != null)
      return false; // Not a phone number/pure index
    return true;
  }

  // Validates that a cell value is a real time string (e.g. "14:30", "2:30 PM") not a header label
  bool _isValidTimeValue(String val) {
    if (val.isEmpty) return false;
    final clean = val.trim();
    // Must contain at least one digit to be a time
    if (!clean.contains(RegExp(r'[0-9]'))) return false;
    // Must contain a colon or dot (time separator)
    if (!clean.contains(RegExp(r'[:\.]'))) return false;
    return true;
  }

  // Standardizes flight numbers to capitalize, fix AL->AI typos, and add standard spacing
  String _normalizeFlightNumber(String flight) {
    String clean = flight.trim().toUpperCase();
    clean = clean
        .replaceAll('|', '')
        .replaceAll('-', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (clean.startsWith('AL') &&
        clean.length > 2 &&
        RegExp(r'[0-9]').hasMatch(clean.substring(2))) {
      clean = 'AI${clean.substring(2)}';
    }
    final match = RegExp(
      r'^([A-Z0-9]{2})([0-9]+)$',
    ).firstMatch(clean.replaceAll(' ', ''));
    if (match != null) {
      final code = match.group(1);
      final num = match.group(2);
      clean = '$code $num';
    }
    return clean;
  }

  // Updates Live ETA dynamically to Column I (actual_time)
  Future<void> writeEta(String sheetName, int row, String eta) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return;

    try {
      final resolvedName = await _resolveSheetTabName(sheetName);
      await _ensureInitialized();
      // Write directly to Column I!
      final writeRange = "'$resolvedName'!I$row";
      await _writeToRange(writeRange, eta);
    } catch (e) {
      print('writeEta error: $e');
    }
  }

  Future<void> _writeToRange(String range, String val) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return;

    final valueRange = sheets.ValueRange.fromJson({
      'values': [
        [val],
      ],
    });
    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      sheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  // Updates tourist checkbox status dynamically to Column A (pick_up) or Column B (drop_off)
  Future<void> writeTouristStatus(
    String sheetName,
    int row,
    String field,
    bool active,
  ) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return;

    try {
      final resolvedName = await _resolveSheetTabName(sheetName);
      await _ensureInitialized();

      final String col = field == 'pickup' ? 'A' : 'B';
      final writeRange = "'$resolvedName'!$col$row";

      final valueRange = sheets.ValueRange.fromJson({
        'values': [
          [active ? 'TRUE' : 'FALSE'],
        ],
      });
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        sheetId,
        writeRange,
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      print('writeTouristStatus error: $e');
    }
  }

  // Updates tourist notes directly to Column O
  Future<void> writeTouristNote(String sheetName, int row, String note) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return;

    try {
      final resolvedName = await _resolveSheetTabName(sheetName);
      await _ensureInitialized();
      final writeRange = "'$resolvedName'!O$row";
      await _writeToRange(writeRange, note);
    } catch (e) {
      print('writeTouristNote error: $e');
    }
  }

  // Resilient datetime parser - handles both colon (2:30) and dot (2.30) formats
  DateTime _parseTime(String val) {
    try {
      return DateTime.parse(val);
    } catch (_) {
      try {
        final separatorRegex = RegExp(r'[:.]');
        final parts = val.trim().split(separatorRegex);
        if (parts.length >= 2) {
          final now = DateTime.now();
          final hour = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
          final minute = int.tryParse(
            parts[1].replaceAll(RegExp(r'[^0-9]'), ''),
          );
          if (hour != null && minute != null) {
            return DateTime(now.year, now.month, now.day, hour, minute);
          }
        }
      } catch (_) {}
    }
    return DateTime.now();
  }

  // Format vehicle type: keep only alphanumeric and single spaces, trim and uppercase
  String _formatVehicleType(String val) {
    String formatted = val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ');
    formatted = formatted.replaceAll(RegExp(r'\s+'), ' ').trim();
    return formatted.toUpperCase();
  }
}
