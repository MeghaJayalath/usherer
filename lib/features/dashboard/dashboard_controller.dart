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
  StreamSubscription<List<TouristGroup>>? _groupsSubscription;

  DashboardController({required String initialDate}) : _date = initialDate {
    _subscribeToGroups();
    TouristRepository.wipeNotifier.addListener(_onWipe);
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
      final timeStr = format.format(group.scheduledTime);

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
