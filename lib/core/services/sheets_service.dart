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

  // Cache of resolved column indices per sheetName:
  // key is sheetName (resolved), value is map of column name -> column index
  static final Map<String, Map<String, int>> _resolvedColumnMappings = {};

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

  // Force re-initialization by clearing the current API instance.
  // Called proactively on app resume (via WidgetsBindingObserver) and as a
  // fallback retry when a write fails on iOS (expired/invalidated auth client).
  Future<void> forceReinitialize() async {
    _sheetsApi = null;
    await _ensureInitialized();
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

  // Fetch all spreadsheet tab titles dynamically
  Future<List<String>> getSheetTabNames() async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return [];

    await _ensureInitialized();

    try {
      final spreadsheet = await _sheetsApi!.spreadsheets.get(sheetId);
      return spreadsheet.sheets
              ?.map((s) => s.properties?.title)
              .whereType<String>()
              .toList() ??
          [];
    } catch (e) {
      print('Error getting sheet tab names: $e');
      return [];
    }
  }

  // Performs case-insensitive, spacing-resilient, and abbreviated month matches (e.g. JUN -> JUNE)
  // Also supports gracefully falling back to a base date sheet (e.g. 3RD JUNE ARR -> 3RD JUNE) if a suffixed sheet is not found.
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

    // 3. Fallback: If target ends with DEP or ARR, strip it and look for the base date match!
    if (cleanTarget.endsWith('DEP') || cleanTarget.endsWith('ARR')) {
      final baseTarget = cleanTarget.substring(0, cleanTarget.length - 3);

      // Try exact match on base date
      for (final title in available) {
        final cleanTitle = title.trim().toUpperCase().replaceAll(' ', '');
        if (cleanTitle == baseTarget) {
          return title;
        }
      }

      // Try abbreviated match on base date
      String baseTargetAlt = baseTarget;
      if (baseTarget.contains('JUNE')) {
        baseTargetAlt = baseTarget.replaceAll('JUNE', 'JUN');
      } else if (baseTarget.contains('JULY')) {
        baseTargetAlt = baseTarget.replaceAll('JULY', 'JUL');
      } else if (baseTarget.contains('SEPTEMBER')) {
        baseTargetAlt = baseTarget.replaceAll('SEPTEMBER', 'SEP');
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

        if (titleAlt == baseTargetAlt) {
          return title;
        }
      }
    }

    return null;
  }

  // Ensures a sheet's column headers are scanned and cached in memory
  Future<Map<String, int>> _ensureColumnMapping(String resolvedName) async {
    if (_resolvedColumnMappings.containsKey(resolvedName)) {
      return _resolvedColumnMappings[resolvedName]!;
    }

    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return {};

    await _ensureInitialized();
    try {
      // Fetch first 10 rows to detect headers
      final response = await _sheetsApi!.spreadsheets.values.get(
        sheetId,
        "'$resolvedName'!A1:Z10",
      );
      final rows = response.values;
      if (rows != null && rows.isNotEmpty) {
        int headerRowIndex = -1;
        Map<String, int> colIndices = {};

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          for (int j = 0; j < row.length; j++) {
            final cell = row[j].toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
            if (cell == 'vehicletype' || cell == 'vehicle') {
              headerRowIndex = i;
              break;
            }
          }
          if (headerRowIndex != -1) {
            final headerRow = rows[headerRowIndex];
            for (int j = 0; j < headerRow.length; j++) {
              final colName = headerRow[j].toString().toLowerCase().trim().replaceAll(' ', '_');
              colIndices[colName] = j;
            }
            break;
          }
        }
        if (colIndices.isNotEmpty) {
          _resolvedColumnMappings[resolvedName] = colIndices;
          return colIndices;
        }
      }
    } catch (e) {
      print('Error ensuring column mapping for $resolvedName: $e');
    }
    return {};
  }

  // Converts a 0-based column index to spreadsheet letter notation (e.g. 0 -> A, 27 -> AB)
  String _colLetter(int index) {
    if (index < 0) return '';
    String letter = '';
    int temp = index;
    while (temp >= 0) {
      letter = String.fromCharCode((temp % 26) + 65) + letter;
      temp = (temp ~/ 26) - 1;
    }
    return letter;
  }

  // Resolves the spreadsheet column letter dynamically by matches with synonyms list
  Future<String> _resolveColumnLetter(
    String resolvedName,
    List<String> synonyms,
    String defaultLetter,
  ) async {
    final colIndices = await _ensureColumnMapping(resolvedName);
    if (colIndices.isEmpty) return defaultLetter;

    for (final syn in synonyms) {
      final normalizedSyn = syn.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
      for (final entry in colIndices.entries) {
        final normalizedCol = entry.key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
        if (normalizedCol == normalizedSyn || normalizedCol.contains(normalizedSyn)) {
          return _colLetter(entry.value);
        }
      }
    }
    return defaultLetter;
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
        "'$resolvedName'!A:Z",
      );

      final rows = response.values;
      if (rows == null || rows.isEmpty) {
        return [];
      }

      // Ensure headers are scanned and cached in _resolvedColumnMappings
      final colIndices = await _ensureColumnMapping(resolvedName);

      int getColIndex(List<String> synonyms, int defaultIdx) {
        if (colIndices.isEmpty) return defaultIdx;
        for (final syn in synonyms) {
          final normalizedSyn = syn.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
          for (final entry in colIndices.entries) {
            final normalizedCol = entry.key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
            if (normalizedCol == normalizedSyn || normalizedCol.contains(normalizedSyn)) {
              return entry.value;
            }
          }
        }
        return defaultIdx;
      }

      // Resolve indices dynamically
      final int idxPickUp = getColIndex(['pick_up', 'pickup'], 0);
      final int idxDropOff = getColIndex(['drop_off', 'dropoff'], 1);
      final int idxVehicleType = getColIndex(['vehicle_type', 'vehicle'], 3);
      final int idxNumberPlate = getColIndex(['number_plate', 'plate', 'vehicle_no'], 4);
      final int idxDriverContact = getColIndex(['driver_contact_info', 'driver_contact', 'driver_phone'], 5);
      final int idxFlightNum = getColIndex(['flight_number', 'flight'], 6);
      final int idxHotelDepTime = getColIndex(['hotel_departure_time', 'hotel_dep', 'departure_time'], -1);
      final int idxScheduledTime = getColIndex(['scheduled_time', 'scheduled'], 7);
      final int idxActualTime = getColIndex(['actual_time', 'actual', 'live_eta', 'eta'], 8);
      final int idxTouristName = getColIndex(['tourist_name', 'name', 'guest_name', 'tourist'], 9);
      final int idxContactInfo = getColIndex(['contact_info', 'contact', 'guest_phone'], 10);
      final int idxPriority = getColIndex(['priority'], 11);
      final int idxHotel = getColIndex(['hotel'], 12);
      final int idxHub = getColIndex(['hub'], 13);
      final int idxNotes = getColIndex(['notes', 'remarks'], 14);

      List<TouristGroup> groups = [];

      String? currentVehicleType;
      String? currentNumberPlate;
      String? currentDriverContactInfo;
      int? currentSheetRow;
      DateTime? currentScheduledTime;
      String? currentLiveEta;
      String? currentHotelDepartureTime;
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
            hotelDepartureTime: currentHotelDepartureTime,
          ),
        );

        // Reset accumulators
        currentTourists.clear();
        currentTouristsFlights.clear();
        currentHotelDepartureTime = null;
      }

      // Start parsing after the header row (if detected, otherwise from row index 1)
      int headerRowIdx = -1;
      if (colIndices.isNotEmpty) {
        for (int i = 0; i < rows.length && i < 10; i++) {
          final row = rows[i];
          for (int j = 0; j < row.length; j++) {
            final cell = row[j].toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
            if (cell == 'vehicletype' || cell == 'vehicle') {
              headerRowIdx = i;
              break;
            }
          }
          if (headerRowIdx != -1) break;
        }
      }
      final startRowIdx = headerRowIdx != -1 ? headerRowIdx + 1 : 1;

      for (int i = startRowIdx; i < rows.length; i++) {
        final row = rows[i];
        final rowIndex = i + 1; // 1-indexed row number in Sheets

        String getCell(int idx) {
          if (idx >= 0 && idx < row.length) {
            return row[idx].toString().trim();
          }
          return '';
        }

        final String colD = getCell(idxVehicleType);
        final String colE = getCell(idxNumberPlate);
        final String colF = getCell(idxDriverContact);
        final String colJ = getCell(idxTouristName);

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
          currentScheduledTime = _parseTime(getCell(idxScheduledTime));
          currentLiveEta = _isValidTimeValue(getCell(idxActualTime)) ? getCell(idxActualTime) : null;
          currentHotelDepartureTime = idxHotelDepTime != -1 && getCell(idxHotelDepTime).isNotEmpty
              ? getCell(idxHotelDepTime)
              : null;
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
          final String colA = getCell(idxPickUp);
          final String colB = getCell(idxDropOff);
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
              priority: getCell(idxPriority),
              hotel: getCell(idxHotel),
              hub: getCell(idxHub),
              notes: getCell(idxNotes),
              contactInfo: getCell(idxContactInfo),
            ),
          );

          final String colG = getCell(idxFlightNum);
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
      final String colLetter = await _resolveColumnLetter(
        resolvedName,
        ['actual_time', 'actual', 'live_eta', 'eta'],
        'I',
      );
      final writeRange = "'$resolvedName'!$colLetter$row";
      await _writeToRange(writeRange, eta);
    } catch (e) {
      print('writeEta error (after retry): $e');
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

    try {
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        sheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      // On iOS the OAuth2 client can expire or get invalidated silently.
      // Re-initialize and retry exactly once before giving up.
      print('_writeToRange failed (may be stale auth), re-initializing and retrying: $e');
      await forceReinitialize();
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        sheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    }
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
      await _writeToRange(writeRange, active ? 'TRUE' : 'FALSE');
    } catch (e) {
      // _writeToRange already retried once internally; this is a final failure.
      print('writeTouristStatus error (after retry): $e');
      rethrow;
    }
  }

  // Updates tourist notes directly to Column O
  Future<void> writeTouristNote(String sheetName, int row, String note) async {
    final sheetId = AppConfig.spreadsheetId;
    if (sheetId == null || sheetId.isEmpty) return;

    try {
      final resolvedName = await _resolveSheetTabName(sheetName);
      await _ensureInitialized();
      final String colLetter = await _resolveColumnLetter(
        resolvedName,
        ['notes', 'remarks'],
        'O',
      );
      final writeRange = "'$resolvedName'!$colLetter$row";
      await _writeToRange(writeRange, note);
    } catch (e) {
      // _writeToRange already retried once internally; this is a final failure.
      print('writeTouristNote error (after retry): $e');
      rethrow;
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
