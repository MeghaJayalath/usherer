import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tourist.dart';
import '../../../data/models/flight.dart';
import 'status_chip.dart';
import 'tourist_tile.dart';
import '../../../data/repositories/flight_repository.dart';

class TouristWithVehicle {
  final Tourist tourist;
  final String vehicleType;
  final String groupId;

  TouristWithVehicle({
    required this.tourist,
    required this.vehicleType,
    required this.groupId,
  });
}

class FlightChunk {
  final String flightNumber;
  final DateTime scheduledTime;
  final String? liveEta;
  final FlightStatus flightStatus;
  final List<TouristWithVehicle> tourists;

  FlightChunk({
    required this.flightNumber,
    required this.scheduledTime,
    this.liveEta,
    required this.flightStatus,
    required this.tourists,
  });
}

class FlightChunkCard extends StatefulWidget {
  final FlightChunk chunk;
  final Function(String groupId, String touristId, String field, bool value)
  onTouristStatusChanged;
  final Function(String groupId, String touristId, String note)
  onTouristNoteChanged;

  const FlightChunkCard({
    super.key,
    required this.chunk,
    required this.onTouristStatusChanged,
    required this.onTouristNoteChanged,
  });

  @override
  State<FlightChunkCard> createState() => _FlightChunkCardState();
}

class _FlightChunkCardState extends State<FlightChunkCard> {
  bool _isExpanded = false;

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

  @override
  Widget build(BuildContext context) {
    final arrivedCount = widget.chunk.tourists
        .where((t) => t.tourist.hasArrived)
        .length;
    final totalCount = widget.chunk.tourists.length;
    final isFlightComplete = arrivedCount == totalCount && totalCount > 0;

    // Get a unique list of vehicles assigned to this flight
    final assignedVehicles = widget.chunk.tourists
        .map((t) => t.vehicleType)
        .toSet()
        .join(', ');

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      // Airplane Icon Container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.getStatusIndicatorBgColor(
                            isComplete: isFlightComplete,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.flight_land_rounded,
                          color: AppColors.getStatusIndicatorColor(
                            isComplete: isFlightComplete,
                          ),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Flight labels and assigned vehicles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.chunk.flightNumber,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.airport_shuttle_outlined,
                                  color: AppColors.textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    assignedVehicles.isEmpty
                                        ? 'No Vehicles'
                                        : assignedVehicles,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status and progress tracker
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(status: widget.chunk.flightStatus),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '$arrivedCount/$totalCount',
                                style: AppTypography.bodySecondary.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isFlightComplete
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
                            'SCHEDULED TIME',
                            style: AppTypography.bodySecondary.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'hh:mm a',
                            ).format(widget.chunk.scheduledTime),
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
                            widget.chunk.flightNumber,
                          );

                          if (isCurrentlyPolling) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'LIVE ETA',
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
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

                          if (widget.chunk.liveEta != null) {
                            final statusColor = AppColors.getFlightStatusColor(
                              widget.chunk.flightStatus,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
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
                                  _formatEtaTo12Hour(widget.chunk.liveEta!),
                                  style: AppTypography.bodyPrimary.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            );
                          }

                          return const SizedBox.shrink();
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
                ...widget.chunk.tourists.map((t) {
                  return TouristTile(
                    tourist: t.tourist,
                    groupId: t.groupId,
                    vehicleLabel: t.vehicleType,
                    onStatusChanged: (field, value) {
                      widget.onTouristStatusChanged(
                        t.groupId,
                        t.tourist.id,
                        field,
                        value,
                      );
                    },
                    onNoteChanged: (note) {
                      widget.onTouristNoteChanged(
                        t.groupId,
                        t.tourist.id,
                        note,
                      );
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
  }
}
