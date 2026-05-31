import 'package:hive/hive.dart';

enum FlightStatus { onTime, delayed, arrived, early, unknown }

extension FlightStatusExtension on FlightStatus {
  String toShortString() {
    switch (this) {
      case FlightStatus.onTime:
        return 'onTime';
      case FlightStatus.delayed:
        return 'delayed';
      case FlightStatus.arrived:
        return 'arrived';
      case FlightStatus.early:
        return 'early';
      case FlightStatus.unknown:
        return 'unknown';
    }
  }

  static FlightStatus fromString(String? status) {
    if (status == null) return FlightStatus.unknown;
    switch (status.toLowerCase()) {
      case 'ontime':
      case 'on_time':
      case 'on-time':
      case 'expected':
      case 'scheduled':
        return FlightStatus.onTime;
      case 'delayed':
        return FlightStatus.delayed;
      case 'early':
        return FlightStatus.early;
      case 'arrived':
      case 'landed':
        return FlightStatus.arrived;
      default:
        return FlightStatus.unknown;
    }
  }

  static FlightStatus calculateStatus({
    required DateTime scheduledTime,
    required String? liveEtaStr,
  }) {
    if (liveEtaStr == null ||
        liveEtaStr.trim().isEmpty ||
        liveEtaStr == 'No ETA') {
      return FlightStatus.unknown;
    }
    try {
      DateTime? liveEta;
      try {
        liveEta = DateTime.parse(liveEtaStr);
      } catch (_) {
        // Handle both colon (2:25) and dot (2.25) separators from the sheet
        final clean = liveEtaStr.trim();
        final separatorRegex = RegExp(r'[:.]');
        final parts = clean.split(separatorRegex);
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
          final minute = int.tryParse(
            parts[1].replaceAll(RegExp(r'[^0-9]'), ''),
          );
          if (hour != null && minute != null) {
            liveEta = DateTime(
              scheduledTime.year,
              scheduledTime.month,
              scheduledTime.day,
              hour,
              minute,
            );
          }
        }
      }

      if (liveEta != null) {
        final scheduledMinutes = scheduledTime.hour * 60 + scheduledTime.minute;
        final liveMinutes = liveEta.hour * 60 + liveEta.minute;

        // Any difference of more than 2 minutes triggers early/delayed
        if (liveMinutes < scheduledMinutes - 2) {
          return FlightStatus.early;
        } else if (liveMinutes > scheduledMinutes + 2) {
          return FlightStatus.delayed;
        } else {
          return FlightStatus.onTime;
        }
      }
    } catch (_) {}
    return FlightStatus.onTime;
  }

  // Standardizes any time string (e.g., "14:30", "14:30:00", "2:30 PM", "14.30") into a clean "HH:mm" format
  static String? normalizeTimeStr(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty || timeStr == 'No ETA') {
      return null;
    }
    try {
      final clean = timeStr.trim().toUpperCase();
      
      // Handle PM/AM formatting
      bool isPm = clean.contains('PM');
      bool isAm = clean.contains('AM');
      String cleanTime = clean.replaceAll(RegExp(r'[A-Z]'), '').trim();
      
      final separatorRegex = RegExp(r'[:.]');
      final parts = cleanTime.split(separatorRegex);
      if (parts.isNotEmpty) {
        int? hour = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        int minute = 0;
        if (parts.length >= 2) {
          minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
        
        if (hour != null) {
          if (isPm && hour < 12) {
            hour += 12;
          } else if (isAm && hour == 12) {
            hour = 0;
          }
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
    } catch (_) {}
    return timeStr.trim();
  }
}

class FlightStatusAdapter extends TypeAdapter<FlightStatus> {
  @override
  final int typeId = 2;

  @override
  FlightStatus read(BinaryReader reader) {
    final index = reader.readByte();
    return FlightStatus.values[index % FlightStatus.values.length];
  }

  @override
  void write(BinaryWriter writer, FlightStatus obj) {
    writer.writeByte(obj.index);
  }
}
