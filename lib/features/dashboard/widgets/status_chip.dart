import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/flight.dart';

class StatusChip extends StatelessWidget {
  final FlightStatus status;

  const StatusChip({super.key, required this.status});

  String _getLabel(FlightStatus status) {
    switch (status) {
      case FlightStatus.onTime:
        return 'ON TIME';
      case FlightStatus.delayed:
        return 'DELAYED';
      case FlightStatus.early:
        return 'EARLY';
      case FlightStatus.arrived:
        return 'ARRIVED';
      case FlightStatus.unknown:
        return 'NO ETA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getStatusChipBgColor(status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getLabel(status),
        style: AppTypography.labelChip.copyWith(
          color: AppColors.getStatusChipTextColor(status),
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
