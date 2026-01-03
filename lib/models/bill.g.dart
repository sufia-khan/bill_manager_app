// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 0;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double,
      dueDate: fields[3] as DateTime,
      repeat: fields[4] as String,
      paid: fields[5] as bool,
      syncStatusValue: fields[6] as String,
      reminderPreferenceValue: fields[8] as String,
      currencyCode: fields[9] as String,
      version: fields[10] as int,
      reminderTimeHour: fields[12] as int? ?? 9, // Default 9 AM for old data
      reminderTimeMinute:
          fields[13] as int? ?? 0, // Default 0 minutes for old data
      updatedAt: fields[7] as DateTime?,
      lastModified: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.repeat)
      ..writeByte(5)
      ..write(obj.paid)
      ..writeByte(6)
      ..write(obj.syncStatusValue)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.reminderPreferenceValue)
      ..writeByte(9)
      ..write(obj.currencyCode)
      ..writeByte(10)
      ..write(obj.version)
      ..writeByte(11)
      ..write(obj.lastModified)
      ..writeByte(12)
      ..write(obj.reminderTimeHour)
      ..writeByte(13)
      ..write(obj.reminderTimeMinute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
