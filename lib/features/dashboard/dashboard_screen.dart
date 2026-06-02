import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'dashboard_controller.dart';
import 'models/dashboard_list_item.dart';
import 'widgets/vehicle_chunk_card.dart';
import '../settings/settings_screen.dart';
import '../../data/models/tourist_group.dart';
import '../../data/local/hive_cache.dart';
import '../../app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardController _controller;
  bool _isAdmin = false;
  bool _autoDatePickerShown = false;
  final _storage = const FlutterSecureStorage();
  final Map<String, GlobalKey> _touristKeys = {};
  final Map<String, GlobalKey<VehicleChunkCardState>> _groupCardKeys = {};
  String? _highlightedTouristId;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchTextController = TextEditingController();

  /// Opens a custom search dialog backed by the live _controller.groups data.
  /// Unlike SearchAnchor, this rebuilds results on every keystroke using
  /// StatefulBuilder, so it never shows stale or empty results.
  void _openSearch() {
    _searchTextController.clear();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = _searchTextController.text.toLowerCase();
            final groups = _controller.groups; // always live snapshot

            final List<({TouristGroup group, dynamic tourist})> results = [];
            for (final group in groups) {
              for (final tourist in group.tourists) {
                if (query.isEmpty || tourist.name.toLowerCase().contains(query)) {
                  results.add((group: group, tourist: tourist));
                }
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: AppColors.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          controller: _searchTextController,
                          autofocus: true,
                          style: AppTypography.bodyPrimary,
                          cursorColor: AppColors.accent,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search tourist name...',
                            hintStyle: AppTypography.bodySecondary,
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
                            suffixIcon: _searchTextController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                                    onPressed: () {
                                      _searchTextController.clear();
                                      setDialogState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.surfaceHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Results
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: results.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_search_outlined,
                                        color: AppColors.textSecondary.withValues(alpha: 0.4), size: 40),
                                    const SizedBox(height: 12),
                                    Text(
                                      query.isEmpty ? 'Start typing to search...' : 'No matching tourists found',
                                      style: AppTypography.bodySecondary.copyWith(fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: results.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppColors.border,
                                  indent: 64,
                                ),
                                itemBuilder: (context, i) {
                                  final group = results[i].group;
                                  final tourist = results[i].tourist;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                      child: Text(
                                        tourist.name.isNotEmpty ? tourist.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      tourist.name,
                                      style: AppTypography.bodyPrimary.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${group.vehicleType.toUpperCase()} (${group.numberPlate ?? "No Plate"}) • ${group.flightNumber}',
                                      style: AppTypography.bodySecondary.copyWith(fontSize: 12),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      _scrollToTourist(group.id, tourist.id);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkAdminStatus() async {
    final status = await _storage.read(key: 'isAdmin') == 'true';
    if (mounted) {
      setState(() {
        _isAdmin = status;
      });
    }
  }

  double _estimateScrollOffset(String groupId) {
    double offset = 0.0;
    for (final item in _controller.listItems) {
      if (item is GroupCardItem && item.group.id == groupId) {
        break;
      }
      if (item is TimeHeaderItem) {
        offset += 50.0; // Header height including padding
      } else if (item is GroupCardItem) {
        offset += 160.0; // Unexpanded card height + vertical margin
      }
    }
    return offset;
  }

  void _scrollToTourist(String groupId, String touristId) async {
    // Give time for keyboard and any overlay transitions to complete
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    var cardKey = _groupCardKeys[groupId];

    // If card key or context is null, scroll to estimated position first to force rendering
    if (cardKey == null || cardKey.currentContext == null) {
      final estOffset = _estimateScrollOffset(groupId);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          estOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
      cardKey = _groupCardKeys[groupId];
    }

    if (!mounted) return;

    // Step 1: Expand the card
    cardKey?.currentState?.expand();

    // Step 2: Wait one frame for layout, then scroll to the group card
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    cardKey ??= _groupCardKeys[groupId];
    if (cardKey != null && cardKey.currentContext != null) {
      await Scrollable.ensureVisible(
        cardKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }

    // Step 3: Wait for AnimatedCrossFade to expand, then scroll to tourist
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final touristKey = _touristKeys[touristId];
    if (touristKey != null && touristKey.currentContext != null) {
      await Scrollable.ensureVisible(
        touristKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
    }

    // Step 4: Trigger the ripple highlight after scroll settles
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _highlightedTouristId = touristId;
    });

    // Step 5: Clear highlight after the pulse animation finishes
    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) {
      setState(() {
        if (_highlightedTouristId == touristId) {
          _highlightedTouristId = null;
        }
      });
    }
  }



  Widget _buildModeToggleOption({
    required String label,
    required IconData icon,
    required bool isDepartureOption,
  }) {
    final currentModeIsDeparture = _controller.date.endsWith(' DEP');
    final isSelected = _controller.date.isNotEmpty && (currentModeIsDeparture == isDepartureOption);
    final isEnabled = _controller.date.isNotEmpty && (isDepartureOption ? _controller.hasDepartureTab : _controller.hasArrivalTab);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isEnabled || isSelected) return;
          final base = _getBaseDate(_controller.date);
          final newDate = isDepartureOption ? '$base DEP' : '$base ARR';
          _controller.changeDate(newDate);
        },
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentMuted : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.bodyPrimary.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.accent : AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBaseDate(String dateStr) {
    return dateStr
        .replaceAll(RegExp(r'\s+DEP(ARTURE)?(S)?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+ARR(IVAL)?(S)?$', caseSensitive: false), '');
  }

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    final todayStr = _getTodayFormatted();
    final cachedDate = HiveCache.getCurrentDate('');

    String initialDate = '';

    if (cachedDate.isNotEmpty) {
      // Normalize date: default to ARR suffix if not present
      String normalizedCachedDate = cachedDate;
      if (!normalizedCachedDate.endsWith(' ARR') && !normalizedCachedDate.endsWith(' DEP')) {
        normalizedCachedDate = '$normalizedCachedDate ARR';
      }

      initialDate = '${todayStr} ARR';
      try {
        final cachedDateTime = _parseSheetDate(normalizedCachedDate);
        final todayDateTime = _parseSheetDate(todayStr);

        final cachedDayOnly = DateTime(
          cachedDateTime.year,
          cachedDateTime.month,
          cachedDateTime.day,
        );
        final todayDayOnly = DateTime(
          todayDateTime.year,
          todayDateTime.month,
          todayDateTime.day,
        );

        if (cachedDayOnly.isBefore(todayDayOnly)) {
          initialDate = '';
        } else {
          initialDate = normalizedCachedDate;
        }
      } catch (_) {
        initialDate = '';
      }
    }

    _controller = DashboardController(initialDate: initialDate);
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!_autoDatePickerShown &&
        _controller.hasLoadedTabStatus &&
        !_controller.dateExistsInSheet) {
      _autoDatePickerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDatePicker(context);
        }
      });
    }
  }

  String _getTodayFormatted() {
    final now = DateTime.now();
    // Custom date format "11TH MAY" or simple fallback
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

  DateTime _parseSheetDate(String dateStr) {
    try {
      // Strip any DEP/ARR suffixes
      final cleanStr = dateStr.trim().toUpperCase()
          .replaceAll(RegExp(r'\s+DEP(ARTURE)?(S)?$'), '')
          .replaceAll(RegExp(r'\s+ARR(IVAL)?(S)?$'), '');
      
      final parts = cleanStr.split(' ');
      if (parts.length < 2) return DateTime.now();

      final dayStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
      final day = int.tryParse(dayStr) ?? 1;

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
      final month = monthNames.indexWhere((m) => monthStr.startsWith(m)) + 1;
      if (month == 0) return DateTime.now();

      final year = DateTime.now().year;
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final parsedTargetDate = _parseSheetDate(_controller.date);
    final initialDate = _controller.findClosestAvailableDate(parsedTargetDate);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: (day) => _controller.isDateAvailable(day),
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AppColors.accent,
                  onPrimary: AppColors.textPrimary,
                  surface: AppColors.surfaceHigh,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            ),
          ],
        );
      },
    );

    if (pickedDate != null) {
      final formattedBase = _formatSheetDate(pickedDate);
      
      // Preserve the current mode suffix
      final isCurrentlyDeparture = _controller.date.endsWith(' DEP');
      final newDate = isCurrentlyDeparture ? '$formattedBase DEP' : '$formattedBase ARR';
      
      _controller.changeDate(newDate);
    }
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

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_autoDatePickerShown &&
        _controller.hasLoadedTabStatus &&
        !_controller.dateExistsInSheet) {
      _autoDatePickerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDatePicker(context);
      });
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final totalExp = _controller.totalExpected;
        final totalArr = _controller.totalArrived;
        final progressRatio = totalExp > 0 ? totalArr / totalExp : 0.0;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            scrolledUnderElevation: 0,
            title: Row(
              children: [
                Image.asset(
                  'assets/icon.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  'USHERER',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: Icon(
                    Icons.sync_rounded,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                  onPressed: () async {
                    try {
                      await _controller.syncFromSheets();
                    } catch (e) {
                      if (context.mounted) {
                        String errorMsg = e.toString();
                        if (errorMsg.startsWith('Exception: ')) {
                          errorMsg = errorMsg.substring(11);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sync failed: $errorMsg'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textPrimary,
                  size: 26,
                ),
                onPressed: () => _openSearch(),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                  size: 26,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  _checkAdminStatus(); // Refresh admin state when settings screen pops back
                  _controller.refreshSubscription(); // Reactively refresh data stream
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
  
                  // Date Header & Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showDatePicker(context),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _controller.date.isEmpty
                                      ? "SELECT DATE"
                                      : _getBaseDate(_controller.date).toUpperCase(),
                                  style: AppTypography.displayHeader,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.accent,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_controller.totalPickedUp} P / ${_controller.totalDroppedOff} D OF $totalExp',
                            style: AppTypography.labelChip.copyWith(
                              color: AppColors.accent,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PICKUP / DROPOFF STAGES',
                            style: AppTypography.bodySecondary.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Arrivals / Departures Segmented Toggle
                  Row(
                    children: [
                      _buildModeToggleOption(
                        label: 'ARRIVALS',
                        icon: Icons.flight_land_rounded,
                        isDepartureOption: false,
                      ),
                      const SizedBox(width: 8),
                      _buildModeToggleOption(
                        label: 'DEPARTURES',
                        icon: Icons.flight_takeoff_rounded,
                        isDepartureOption: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
  
                  // Animated Progress Bar (thin with coral fill)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: AppColors.border,
                      child: Stack(
                        children: [
                          AnimatedFractionallySizedBox(
                            widthFactor: progressRatio.clamp(0.0, 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
  
                  // Groups ListView
                  Expanded(
                    child: Stack(
                      children: [
                        _controller.groups.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      AppConfig.spreadsheetId == null ||
                                              AppConfig.spreadsheetId!.isEmpty
                                          ? Icons.link_off_outlined
                                          : Icons.inbox_outlined,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppConfig.spreadsheetId == null ||
                                              AppConfig.spreadsheetId!.isEmpty
                                          ? 'No Sheet Configured'
                                          : (_controller.date.isEmpty
                                              ? 'No Date Selected'
                                              : 'No Groups Synchronized'),
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppConfig.spreadsheetId == null ||
                                              AppConfig.spreadsheetId!.isEmpty
                                          ? 'Go to Settings to set up your Google Sheet.'
                                          : (_controller.date.isEmpty
                                              ? 'Tap the calendar header above to select a date.'
                                              : 'Tap the sync button or pick another date.'),
                                      style: AppTypography.bodySecondary,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : CustomScrollView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                cacheExtent: 600,
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    sliver: SliverList.builder(
                                      itemCount: _controller.listItems.length,
                                      itemBuilder: (context, index) {
                                        final item = _controller.listItems[index];
                                        return switch (item) {
                                          TimeHeaderItem() => _buildTimeHeader(item),
                                          GroupCardItem() => _buildGroupCard(item.group),
                                        };
                                      },
                                    ),
                                  ),
                                ],
                              ),
  
                        // Premium glassmorphism blur overlay during background sync / loading
                        if (_controller.isLoading)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 3.5,
                                  sigmaY: 3.5,
                                ),
                                child: Container(
                                  color: AppColors.background.withValues(
                                    alpha: 0.35,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.accent,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeHeader(TimeHeaderItem item) {
    return Padding(
      padding: EdgeInsets.only(
        top: item.isFirst ? 8.0 : 20.0,
        bottom: 8.0,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            item.timeStr.toUpperCase(),
            style: AppTypography.labelChip.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: AppColors.border,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(TouristGroup group) {
    final groupKey = _groupCardKeys.putIfAbsent(
      group.id,
      () => GlobalKey<VehicleChunkCardState>(),
    );
    return VehicleChunkCard(
      key: groupKey,
      group: group,
      touristKeys: _touristKeys,
      highlightedTouristId: _highlightedTouristId,
      onTouristStatusChanged: (touristId, field, value) {
        _controller.markTouristStatus(
          groupId: group.id,
          touristId: touristId,
          field: field,
          value: value,
        );
      },
      onTouristNoteChanged: (touristId, note) {
        _controller.updateTouristNote(
          groupId: group.id,
          touristId: touristId,
          note: note,
        );
      },
    );
  }
}
