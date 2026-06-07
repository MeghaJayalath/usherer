import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/tourist_group.dart';
import '../../data/models/tourist.dart';
import '../../data/models/flight.dart';
import '../../data/repositories/tourist_repository.dart';
import '../../data/local/hive_cache.dart';
import '../../core/services/notification_service.dart';
import 'models/dashboard_list_item.dart';

class DashboardController extends ChangeNotifier {
  String _date;
  List<TouristGroup> _groups = [];
  List<DashboardListItem> _listItems = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;
  bool _hasArrivalTab = true;
  bool _hasDepartureTab = true;
  bool _hasLoadedTabStatus = false;
  bool _dateExistsInSheet = true;
  List<String> _sheetTabNames = [];
  StreamSubscription<List<TouristGroup>>? _groupsSubscription;

  DashboardController({required String initialDate}) : _date = initialDate {
    _subscribeToGroups();
    TouristRepository.wipeNotifier.addListener(_onWipe);
    updateTabStatus();
  }

  bool get hasArrivalTab => _hasArrivalTab;
  bool get hasDepartureTab => _hasDepartureTab;
  bool get hasLoadedTabStatus => _hasLoadedTabStatus;
  bool get dateExistsInSheet => _dateExistsInSheet;
  List<String> get sheetTabNames => _sheetTabNames;

  String getBaseDate(String dateStr) {
    return dateStr
        .replaceAll(RegExp(r'\s+DEP(ARTURE)?(S)?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+ARR(IVAL)?(S)?$', caseSensitive: false), '');
  }

  String _formatSheetDate(DateTime date) {
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
    final monthStr = monthNames[date.month - 1];

    String suffix = 'TH';
    final day = date.day;
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

  List<DateTime> getAvailableDates() {
    final List<DateTime> dates = [];
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
    for (final title in _sheetTabNames) {
      try {
        final cleanStr = title.trim().toUpperCase()
            .replaceAll(RegExp(r'\s+DEP(ARTURE)?(S)?$'), '')
            .replaceAll(RegExp(r'\s+ARR(IVAL)?(S)?$'), '');
        
        final parts = cleanStr.split(' ');
        if (parts.length < 2) continue;

        final dayStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
        final day = int.tryParse(dayStr);
        if (day == null) continue;

        final monthStr = parts[1];
        final month = monthNames.indexWhere((m) => monthStr.startsWith(m)) + 1;
        if (month == 0) continue;

        final year = DateTime.now().year;
        final parsedDate = DateTime(year, month, day);
        final dayOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        if (!dates.any((d) => d.year == dayOnly.year && d.month == dayOnly.month && d.day == dayOnly.day)) {
          dates.add(dayOnly);
        }
      } catch (_) {
        // Ignore non-date tabs like 'Dashboard'
      }
    }
    return dates;
  }

  DateTime findClosestAvailableDate(DateTime target) {
    final avail = getAvailableDates();
    if (avail.isEmpty) return target;

    final targetDayOnly = DateTime(target.year, target.month, target.day);
    if (avail.any((d) => d.year == targetDayOnly.year && d.month == targetDayOnly.month && d.day == targetDayOnly.day)) {
      return targetDayOnly;
    }

    DateTime closest = avail.first;
    int minDiff = (avail.first.difference(targetDayOnly).inDays).abs();
    for (final d in avail) {
      final diff = (d.difference(targetDayOnly).inDays).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = d;
      }
    }
    return closest;
  }

  bool isDateAvailable(DateTime dateTime) {
    if (_sheetTabNames.isEmpty) {
      return true;
    }
    final formattedBase = _formatSheetDate(dateTime).toUpperCase().replaceAll(' ', '');

    for (final title in _sheetTabNames) {
      final cleanTitle = title.trim().toUpperCase().replaceAll(' ', '');
      
      String titleAlt = cleanTitle;
      if (cleanTitle.contains('JUNE')) {
        titleAlt = cleanTitle.replaceAll('JUNE', 'JUN');
      } else if (cleanTitle.contains('JULY')) {
        titleAlt = cleanTitle.replaceAll('JULY', 'JUL');
      } else if (cleanTitle.contains('SEPTEMBER')) {
        titleAlt = cleanTitle.replaceAll('SEPTEMBER', 'SEP');
      }

      String target1 = formattedBase + 'ARR';
      String target2 = formattedBase + 'DEP';
      String target3 = formattedBase;
      
      String formattedBaseAlt = formattedBase;
      if (formattedBase.contains('JUNE')) {
        formattedBaseAlt = formattedBase.replaceAll('JUNE', 'JUN');
      } else if (formattedBase.contains('JULY')) {
        formattedBaseAlt = formattedBase.replaceAll('JULY', 'JUL');
      } else if (formattedBase.contains('SEPTEMBER')) {
        formattedBaseAlt = formattedBase.replaceAll('SEPTEMBER', 'SEP');
      }
      
      String target1Alt = formattedBaseAlt + 'ARR';
      String target2Alt = formattedBaseAlt + 'DEP';
      String target3Alt = formattedBaseAlt;

      if (titleAlt == target1 ||
          titleAlt == target1Alt ||
          titleAlt == target2 ||
          titleAlt == target2Alt ||
          titleAlt == target3 ||
          titleAlt == target3Alt) {
        return true;
      }
    }
    return false;
  }

  Future<void> updateTabStatus() async {
    try {
      final titles = await TouristRepository.getSheetTabNames();
      _sheetTabNames = titles;
      if (titles.isEmpty) {
        _hasArrivalTab = true;
        _hasDepartureTab = true;
        _dateExistsInSheet = true;
        notifyListeners();
        return;
      }

      final base = getBaseDate(_date).toUpperCase().replaceAll(' ', '');
      
      bool arrivalMatch = false;
      bool departureMatch = false;

      bool matchesDate(String title, String targetSuffix) {
        final cleanTitle = title.trim().toUpperCase().replaceAll(' ', '');
        
        String titleAlt = cleanTitle;
        if (cleanTitle.contains('JUNE')) {
          titleAlt = cleanTitle.replaceAll('JUNE', 'JUN');
        } else if (cleanTitle.contains('JULY')) {
          titleAlt = cleanTitle.replaceAll('JULY', 'JUL');
        } else if (cleanTitle.contains('SEPTEMBER')) {
          titleAlt = cleanTitle.replaceAll('SEPTEMBER', 'SEP');
        }

        String target1 = base + targetSuffix;
        String target2 = base;
        if (base.contains('JUNE')) {
          target2 = base.replaceAll('JUNE', 'JUN');
        } else if (base.contains('JULY')) {
          target2 = base.replaceAll('JULY', 'JUL');
        } else if (base.contains('SEPTEMBER')) {
          target2 = base.replaceAll('SEPTEMBER', 'SEP');
        }
        String target1Alt = target2 + targetSuffix;

        return titleAlt == target1 || titleAlt == target1Alt || (targetSuffix == 'ARR' && (titleAlt == base || titleAlt == target2));
      }

      for (final title in titles) {
        if (matchesDate(title, 'ARR')) {
          arrivalMatch = true;
        }
        if (matchesDate(title, 'DEP')) {
          departureMatch = true;
        }
      }

      _hasArrivalTab = arrivalMatch;
      _hasDepartureTab = departureMatch;
      _dateExistsInSheet = arrivalMatch || departureMatch;

      // Fallback: if both are false, it means the base date doesn't exist in sheet titles at all.
      // Keep both active so we don't lock the user out.
      if (!_hasArrivalTab && !_hasDepartureTab) {
        _hasArrivalTab = true;
        _hasDepartureTab = true;
      } else {
        // If current selected mode is not available, auto-switch to the other!
        final currentIsDeparture = _date.endsWith(' DEP');
        if (currentIsDeparture && !_hasDepartureTab && _hasArrivalTab) {
          final baseDate = getBaseDate(_date);
          _date = '$baseDate ARR';
          await HiveCache.setCurrentDate(_date);
          _subscribeToGroups();
        } else if (!currentIsDeparture && !_hasArrivalTab && _hasDepartureTab) {
          final baseDate = getBaseDate(_date);
          _date = '$baseDate DEP';
          await HiveCache.setCurrentDate(_date);
          _subscribeToGroups();
        }
      }
    } catch (e) {
      print('updateTabStatus error: $e');
    } finally {
      _hasLoadedTabStatus = true;
      notifyListeners();
    }
  }

  String get date => _date;
  List<TouristGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  List<DashboardListItem> get listItems => _listItems;

  void _updateListItems() {
    final items = <DashboardListItem>[];
    final format = DateFormat('hh:mm a');
    String? lastTimeStr;

    for (int i = 0; i < _groups.length; i++) {
      final group = _groups[i];
      
      String timeStr;
      final parsedHotelDep = group.getParsedHotelDepartureTime();
      if (parsedHotelDep != null) {
        timeStr = format.format(parsedHotelDep);
      } else if (group.hotelDepartureTime != null && group.hotelDepartureTime!.isNotEmpty) {
        timeStr = group.hotelDepartureTime!;
      } else {
        timeStr = format.format(group.scheduledTime);
      }

      if (timeStr != lastTimeStr) {
        items.add(TimeHeaderItem(timeStr: timeStr, isFirst: i == 0));
        lastTimeStr = timeStr;
      }
      items.add(GroupCardItem(group));
    }
    _listItems = items;
  }

  int get totalExpected {
    int count = 0;
    for (final group in _groups) {
      count += group.tourists.length;
    }
    return count;
  }

  int get totalArrived {
    int count = 0;
    for (final group in _groups) {
      for (final tourist in group.tourists) {
        if (tourist.hasArrived) {
          count++;
        }
      }
    }
    return count;
  }

  int get totalPickedUp {
    int count = 0;
    for (final group in _groups) {
      for (final tourist in group.tourists) {
        if (tourist.pickUp) {
          count++;
        }
      }
    }
    return count;
  }

  int get totalDroppedOff {
    int count = 0;
    for (final group in _groups) {
      for (final tourist in group.tourists) {
        if (tourist.dropOff) {
          count++;
        }
      }
    }
    return count;
  }

  void _subscribeToGroups() {
    _groupsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    // Start listening to the repository Firestore stream
    _groupsSubscription = TouristRepository.watchGroups(_date).listen(
      (updatedGroups) {
        // Detect flight time (liveEta) updates to trigger local notifications
        if (_groups.isNotEmpty) {
          final Set<String> notifiedFlights = {};

          for (final newGroup in updatedGroups) {
            // Find corresponding group in our current state list
            final oldGroup = _groups.firstWhere(
              (g) => g.id == newGroup.id,
              orElse: () => newGroup,
            );

            final oldEta = oldGroup.liveEta;
            final newEta = newGroup.liveEta;

            final normOldEta = FlightStatusExtension.normalizeTimeStr(oldEta);
            final normNewEta = FlightStatusExtension.normalizeTimeStr(newEta);

            // Only trigger a notification if the ETA has actually changed between valid times
            if (normOldEta != null &&
                normNewEta != null &&
                normOldEta != normNewEta) {
              final flightNum = newGroup.flightNumber;
              if (!notifiedFlights.contains(flightNum)) {
                notifiedFlights.add(flightNum);
                NotificationService.showNotification(
                  id: flightNum.hashCode,
                  title: 'Flight $flightNum Status Update',
                  body: 'New ETA is $newEta',
                );
              }
            }
          }
        }

        _groups = updatedGroups;
        _updateListItems();

        // If we're in a manual sync, resolve the completer so the blur waits for this
        if (_isSyncing &&
            _syncCompleter != null &&
            !_syncCompleter!.isCompleted) {
          _syncCompleter!.complete();
        }

        // Only auto-clear loading if NOT in a manual sync (manual sync controls its own lifecycle)
        if (!_isSyncing) {
          _isLoading = false;
        }
        notifyListeners();
      },
      onError: (error) {
        print('Error watching groups in controller: $error');
        if (_isSyncing &&
            _syncCompleter != null &&
            !_syncCompleter!.isCompleted) {
          _syncCompleter!.completeError(error);
        }
        _isLoading = false;
        _isSyncing = false;
        notifyListeners();
      },
    );
  }

  // Called instantly when wipeAllData fires - clears in-memory state immediately
  void _onWipe() {
    _groupsSubscription?.cancel();
    _groups = [];
    _listItems = [];
    _isLoading = false;
    _isSyncing = false;
    notifyListeners();
    // Re-subscribe so we still get future Firestore updates (empty stream)
    _subscribeToGroups();
  }

  // Triggered when coordinator picks a new date tab in Settings
  Future<void> changeDate(String newDate) async {
    if (_date == newDate) return;

    _date = newDate;
    await HiveCache.setCurrentDate(newDate);

    _subscribeToGroups();
    
    // Dynamically update available tabs status
    updateTabStatus();

    // Proactively pull latest data from Google Sheets in the background to initialize Firestore
    try {
      await TouristRepository.loadAndSyncFromSheets(newDate);
    } catch (e) {
      print('Background Sheets sync failed on date change: $e');
    }
  }

  // Sync back on tourist check-in
  Future<void> markTouristStatus({
    required String groupId,
    required String touristId,
    required String field, // 'pickup' or 'dropoff'
    required bool value,
  }) async {
    // Find matching group and tourist to get sheets row number
    TouristGroup? targetGroup;
    Tourist? targetTourist;

    for (final g in _groups) {
      if (g.id == groupId) {
        targetGroup = g;
        for (final t in g.tourists) {
          if (t.id == touristId) {
            targetTourist = t;
            break;
          }
        }
        break;
      }
    }

    if (targetGroup == null || targetTourist == null) return;

    // Optimistically update local memory state immediately for instant feedback
    if (field == 'pickup') {
      targetTourist.pickUp = value;
    } else if (field == 'dropoff') {
      targetTourist.dropOff = value;
    }
    targetTourist.hasArrived = targetTourist.pickUp && targetTourist.dropOff;
    targetTourist.arrivedAt = (targetTourist.pickUp || targetTourist.dropOff)
        ? DateTime.now().toIso8601String()
        : null;
    targetTourist.markedBy = 'Coordinator';
    notifyListeners();

    // Perform background repository update
    try {
      await TouristRepository.markTouristStatus(
        date: _date,
        groupId: groupId,
        touristId: touristId,
        field: field,
        value: value,
        sheetRow: targetTourist.sheetRow,
      );
    } catch (e) {
      print('Controller failed to persist status: $e');
    }
  }

  // Update tourist note
  Future<void> updateTouristNote({
    required String groupId,
    required String touristId,
    required String note,
  }) async {
    TouristGroup? targetGroup;
    Tourist? targetTourist;

    for (final g in _groups) {
      if (g.id == groupId) {
        targetGroup = g;
        for (final t in g.tourists) {
          if (t.id == touristId) {
            targetTourist = t;
            break;
          }
        }
        break;
      }
    }

    if (targetGroup == null || targetTourist == null) return;

    // Optimistically update local memory state immediately for instant feedback
    targetTourist.notes = note;
    notifyListeners();

    // Perform background repository update
    try {
      await TouristRepository.updateTouristNote(
        date: _date,
        groupId: groupId,
        touristId: touristId,
        note: note,
        sheetRow: targetTourist.sheetRow,
      );
    } catch (e) {
      print('Controller failed to update note: $e');
    }
  }

  // Manually fetch latest data from Google Sheets, update Firestore, and local Hive cache.
  // Keeps the blur overlay active until the Firestore stream delivers the fresh data.
  Future<void> syncFromSheets() async {
    _isSyncing = true;
    _isLoading = true;
    _syncCompleter = Completer<void>();
    notifyListeners();

    try {
      // Write sheet data to Firestore
      await TouristRepository.loadAndSyncFromSheets(_date);

      // Dynamically update available tabs status (in case user added new tabs or renamed them)
      await updateTabStatus();

      // Now wait for the Firestore stream to deliver the updated snapshot (with a safety timeout)
      await _syncCompleter!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          // If the stream hasn't fired in 8s, release anyway
        },
      );
    } catch (e) {
      print('Manual Sheets sync failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      _isLoading = false;
      _syncCompleter = null;
      notifyListeners();
    }
  }

  void refreshSubscription() {
    _subscribeToGroups();
  }

  @override
  void dispose() {
    TouristRepository.wipeNotifier.removeListener(_onWipe);
    _groupsSubscription?.cancel();
    super.dispose();
  }
}
