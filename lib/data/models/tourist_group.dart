import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tourist.dart';
import 'flight.dart';

class TouristGroup {
  final String id;
  final String vehicleType; // "Van", "Bus", "SUV"
  final String vehicleLabel; // "Van 1"
  final DateTime scheduledTime;
  final String flightNumber;
  String? liveEta;
  FlightStatus flightStatus;
  List<Tourist> tourists;
  final int? sheetRow; // First row of this group in Google Sheets
  final String? numberPlate;
  final String? driverContactInfo;

  TouristGroup({
    required this.id,
    required this.vehicleType,
    required this.vehicleLabel,
    required this.scheduledTime,
    required this.flightNumber,
    this.liveEta,
    required this.flightStatus,
    required List<Tourist> tourists,
    this.sheetRow,
    this.numberPlate,
    this.driverContactInfo,
  }) : tourists = List<Tourist>.from(tourists) {
    this.tourists.sort((a, b) {
      if (a.sheetRow != null && b.sheetRow != null) {
        return a.sheetRow!.compareTo(b.sheetRow!);
      }
      return a.id.compareTo(b.id);
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleType': vehicleType,
      'vehicleLabel': vehicleLabel,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'flightNumber': flightNumber,
      'liveEta': liveEta,
      'flightStatus': flightStatus.toShortString(),
      'tourists': tourists.map((t) => t.toMap()).toList(),
      'sheetRow': sheetRow,
      'numberPlate': numberPlate,
      'driverContactInfo': driverContactInfo,
    };
  }

  factory TouristGroup.fromMap(Map<String, dynamic> map, String docId) {
    var touristsData = map['tourists'] as List<dynamic>? ?? [];
    List<Tourist> touristsList = touristsData.map((t) {
      if (t is Map) {
        return Tourist.fromMap(Map<String, dynamic>.from(t));
      }
      return Tourist.fromMap({});
    }).toList();

    DateTime schedTime;
    var rawTime = map['scheduledTime'];
    if (rawTime is Timestamp) {
      schedTime = rawTime.toDate();
    } else if (rawTime is String) {
      schedTime = DateTime.parse(rawTime);
    } else if (rawTime is int) {
      schedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else {
      schedTime = DateTime.now();
    }

    return TouristGroup(
      id: docId,
      vehicleType: map['vehicleType'] ?? '',
      vehicleLabel: map['vehicleLabel'] ?? '',
      scheduledTime: schedTime,
      flightNumber: map['flightNumber'] ?? '',
      liveEta: map['liveEta'],
      flightStatus: FlightStatusExtension.fromString(map['flightStatus']),
      tourists: touristsList,
      sheetRow: map['sheetRow'] as int?,
      numberPlate: map['numberPlate'],
      driverContactInfo: map['driverContactInfo'],
    );
  }

  TouristGroup copyWith({
    String? id,
    String? vehicleType,
    String? vehicleLabel,
    DateTime? scheduledTime,
    String? flightNumber,
    String? liveEta,
    FlightStatus? flightStatus,
    List<Tourist>? tourists,
    int? sheetRow,
    String? numberPlate,
    String? driverContactInfo,
  }) {
    return TouristGroup(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      flightNumber: flightNumber ?? this.flightNumber,
      liveEta: liveEta ?? this.liveEta,
      flightStatus: flightStatus ?? this.flightStatus,
      tourists: tourists ?? this.tourists,
      sheetRow: sheetRow ?? this.sheetRow,
      numberPlate: numberPlate ?? this.numberPlate,
      driverContactInfo: driverContactInfo ?? this.driverContactInfo,
    );
  }
}

class TouristGroupAdapter extends TypeAdapter<TouristGroup> {
  @override
  final int typeId = 0;

  @override
  TouristGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TouristGroup(
      id: fields[0] as String,
      vehicleType: fields[1] as String,
      vehicleLabel: fields[2] as String,
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      flightNumber: fields[4] as String,
      liveEta: fields[5] as String?,
      flightStatus: fields[6] as FlightStatus,
      tourists: (fields[7] as List).cast<Tourist>(),
      sheetRow: fields[8] as int?,
      numberPlate: fields[9] as String?,
      driverContactInfo: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TouristGroup obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vehicleType)
      ..writeByte(2)
      ..write(obj.vehicleLabel)
      ..writeByte(3)
      ..write(obj.scheduledTime.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.flightNumber)
      ..writeByte(5)
      ..write(obj.liveEta)
      ..writeByte(6)
      ..write(obj.flightStatus)
      ..writeByte(7)
      ..write(obj.tourists)
      ..writeByte(8)
      ..write(obj.sheetRow)
      ..writeByte(9)
      ..write(obj.numberPlate)
      ..writeByte(10)
      ..write(obj.driverContactInfo);
  }
}
