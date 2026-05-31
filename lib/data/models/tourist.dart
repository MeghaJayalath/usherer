import 'package:hive/hive.dart';

class Tourist {
  final String id;
  final String name;
  bool hasArrived;
  String? arrivedAt;
  String? markedBy;
  final int? sheetRow; // Keep track of the specific row in Google Sheets
  bool pickUp;
  bool dropOff;
  final String? priority;
  final String? hotel;
  final String? hub;
  String? notes;
  final String? contactInfo;

  Tourist({
    required this.id,
    required this.name,
    required this.hasArrived,
    this.arrivedAt,
    this.markedBy,
    this.sheetRow,
    this.pickUp = false,
    this.dropOff = false,
    this.priority,
    this.hotel,
    this.hub,
    this.notes,
    this.contactInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hasArrived': hasArrived,
      'arrivedAt': arrivedAt,
      'markedBy': markedBy,
      'sheetRow': sheetRow,
      'pickUp': pickUp,
      'dropOff': dropOff,
      'priority': priority,
      'hotel': hotel,
      'hub': hub,
      'notes': notes,
      'contactInfo': contactInfo,
    };
  }

  factory Tourist.fromMap(Map<String, dynamic> map) {
    return Tourist(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      hasArrived: map['hasArrived'] ?? false,
      arrivedAt: map['arrivedAt'],
      markedBy: map['markedBy'],
      sheetRow: map['sheetRow'] as int?,
      pickUp: map['pickUp'] ?? false,
      dropOff: map['dropOff'] ?? false,
      priority: map['priority'],
      hotel: map['hotel'],
      hub: map['hub'],
      notes: map['notes'],
      contactInfo: map['contactInfo'],
    );
  }

  Tourist copyWith({
    String? id,
    String? name,
    bool? hasArrived,
    String? arrivedAt,
    String? markedBy,
    int? sheetRow,
    bool? pickUp,
    bool? dropOff,
    String? priority,
    String? hotel,
    String? hub,
    String? notes,
    String? contactInfo,
  }) {
    return Tourist(
      id: id ?? this.id,
      name: name ?? this.name,
      hasArrived: hasArrived ?? this.hasArrived,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      markedBy: markedBy ?? this.markedBy,
      sheetRow: sheetRow ?? this.sheetRow,
      pickUp: pickUp ?? this.pickUp,
      dropOff: dropOff ?? this.dropOff,
      priority: priority ?? this.priority,
      hotel: hotel ?? this.hotel,
      hub: hub ?? this.hub,
      notes: notes ?? this.notes,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}

class TouristAdapter extends TypeAdapter<Tourist> {
  @override
  final int typeId = 1;

  @override
  Tourist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tourist(
      id: fields[0] as String,
      name: fields[1] as String,
      hasArrived: fields[2] as bool,
      arrivedAt: fields[3] as String?,
      markedBy: fields[4] as String?,
      sheetRow: fields[5] as int?,
      pickUp: fields[6] as bool? ?? false,
      dropOff: fields[7] as bool? ?? false,
      priority: fields[8] as String?,
      hotel: fields[9] as String?,
      hub: fields[10] as String?,
      notes: fields[11] as String?,
      contactInfo: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Tourist obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.hasArrived)
      ..writeByte(3)
      ..write(obj.arrivedAt)
      ..writeByte(4)
      ..write(obj.markedBy)
      ..writeByte(5)
      ..write(obj.sheetRow)
      ..writeByte(6)
      ..write(obj.pickUp)
      ..writeByte(7)
      ..write(obj.dropOff)
      ..writeByte(8)
      ..write(obj.priority)
      ..writeByte(9)
      ..write(obj.hotel)
      ..writeByte(10)
      ..write(obj.hub)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.contactInfo);
  }
}
