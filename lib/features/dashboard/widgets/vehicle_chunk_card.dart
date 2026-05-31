import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tourist_group.dart';
import 'status_chip.dart';
import 'tourist_tile.dart';
import '../../../data/repositories/flight_repository.dart';

class VehicleChunkCard extends StatefulWidget {
  final TouristGroup group;
  final Function(String touristId, String field, bool value) onTouristStatusChanged;
  final Function(String touristId, String note) onTouristNoteChanged;
  final Map<String, GlobalKey> touristKeys;
  final String? highlightedTouristId;

  const VehicleChunkCard({
    super.key,
    required this.group,
    required this.onTouristStatusChanged,
    required this.onTouristNoteChanged,
    required this.touristKeys,
    this.highlightedTouristId,
  });

  @override
  State<VehicleChunkCard> createState() => VehicleChunkCardState();
}

class VehicleChunkCardState extends State<VehicleChunkCard> {
  bool _isExpanded = false;

  void expand() {
    if (!_isExpanded) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  String _formatEtaTo12Hour(String etaStr) {
    try {
      final clean = etaStr.trim();
      if (clean.toLowerCase() == 'no eta') return clean;

      if (clean.toUpperCase().contains('AM') ||
          clean.toUpperCase().contains('PM')) {
        return clean;
      }

      final parts = clean.split(RegExp(r'[:.]'));
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        final minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        if (hour != null && minute != null) {
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour % 12 == 0 ? 12 : hour % 12;
          final displayMinute = minute.toString().padLeft(2, '0');
          return '$displayHour:$displayMinute $period';
        }
      }
    } catch (_) {}
    return etaStr;
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bus':
        return Icons.directions_bus_filled_outlined;
      case 'suv':
        return Icons.directions_car_outlined;
      case 'van':
      default:
        return Icons.airport_shuttle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrivedCount = widget.group.tourists
        .where((t) => t.hasArrived)
        .length;
    final totalCount = widget.group.tourists.length;
    final isGroupComplete = arrivedCount == totalCount && totalCount > 0;

    final hasDriver = widget.group.driverContactInfo != null && widget.group.driverContactInfo!.isNotEmpty;

    Widget cardContent = Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header details of vehicle
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Icon Container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.getStatusIndicatorBgColor(
                            isComplete: isGroupComplete,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getVehicleIcon(widget.group.vehicleType),
                          color: AppColors.getStatusIndicatorColor(
                            isComplete: isGroupComplete,
                          ),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Vehicle Labels & Number Plate Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.vehicleLabel,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (widget.group.numberPlate != null && widget.group.numberPlate!.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.group.numberPlate!,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_car_outlined,
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'No Number Plate',
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Flight status chip & arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(status: widget.group.flightStatus),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '$arrivedCount/$totalCount',
                                style: AppTypography.bodySecondary.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isGroupComplete
                                      ? AppColors.arrived
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  // Time section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHEDULED',
                            style: AppTypography.bodySecondary.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'hh:mm a',
                            ).format(widget.group.scheduledTime),
                            style: AppTypography.bodyPrimary.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: FlightRepository.pollingFlights,
                        builder: (context, pollingSet, _) {
                          final isCurrentlyPolling = pollingSet.contains(
                            widget.group.flightNumber,
                          );

                          if (isCurrentlyPolling) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flight_land,
                                      size: 12,
                                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.group.flightNumber,
                                      style: AppTypography.bodySecondary.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'LIVE ETA',
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.accent,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'UPDATING',
                                      style: AppTypography.bodySecondary
                                          .copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accent,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          if (widget.group.liveEta != null) {
                            final statusColor = AppColors.getFlightStatusColor(
                              widget.group.flightStatus,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flight_land,
                                      size: 12,
                                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.group.flightNumber,
                                      style: AppTypography.bodySecondary.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'LIVE ETA',
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatEtaTo12Hour(widget.group.liveEta!),
                                  style: AppTypography.bodyPrimary.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flight_land,
                                    size: 12,
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.group.flightNumber,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'LIVE ETA',
                                style: AppTypography.bodySecondary.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PENDING',
                                style: AppTypography.bodyPrimary.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable tourists list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                const SizedBox(height: 10),
                ...widget.group.tourists.map((tourist) {
                  return TouristTile(
                    key: widget.touristKeys[tourist.id] ??= GlobalKey(),
                    tourist: tourist,
                    groupId: widget.group.id,
                    isHighlighted: tourist.id == widget.highlightedTouristId,
                    onStatusChanged: (field, value) {
                      widget.onTouristStatusChanged(tourist.id, field, value);
                    },
                    onNoteChanged: (note) {
                      widget.onTouristNoteChanged(tourist.id, note);
                    },
                  );
                }).toList(),
                const SizedBox(height: 12),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );

    if (hasDriver) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Static background revealed under the swipe
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF007AFF),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CALL DRIVER (${widget.group.driverContactInfo})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              // The Dismissible itself
              Dismissible(
                key: ValueKey('dismiss_driver_${widget.group.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    HapticFeedback.mediumImpact();
                    final String cleanNumber = widget.group.driverContactInfo!.replaceAll(RegExp(r'[^0-9+]'), '');
                    final Uri telUri = Uri(scheme: 'tel', path: cleanNumber);
                    try {
                      // Direct launch with non-browser application mode for maximum dialer compatibility
                      final success = await launchUrl(
                        telUri,
                        mode: LaunchMode.externalNonBrowserApplication,
                      );
                      if (!success) {
                        // Try standard external app fallback
                        await launchUrl(
                          telUri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open dialer: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                  return false; // Snap back
                },
                background: const SizedBox.shrink(),
                secondaryBackground: const SizedBox.shrink(),
                child: cardContent,
              ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: cardContent,
      );
    }
  }
}
