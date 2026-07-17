import 'package:hive_ce/hive.dart';

/// A weight and body composition measurement entry.
class WeightEntry extends HiveObject {
  String id;
  double weightKg;
  DateTime date;
  String? note;

  // Body Composition metrics (optional/estimations)
  double? waistCm;
  double? neckCm;
  double? hipCm;
  double? bodyFatPercentage;
  double? bmi;
  double? leanMassKg;
  double? fatMassKg;

  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.date,
    this.note,
    this.waistCm,
    this.neckCm,
    this.hipCm,
    this.bodyFatPercentage,
    this.bmi,
    this.leanMassKg,
    this.fatMassKg,
  });

  WeightEntry copyWith({
    String? id,
    double? weightKg,
    DateTime? date,
    String? note,
    double? waistCm,
    double? neckCm,
    double? hipCm,
    double? bodyFatPercentage,
    double? bmi,
    double? leanMassKg,
    double? fatMassKg,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      date: date ?? this.date,
      note: note ?? this.note,
      waistCm: waistCm ?? this.waistCm,
      neckCm: neckCm ?? this.neckCm,
      hipCm: hipCm ?? this.hipCm,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      bmi: bmi ?? this.bmi,
      leanMassKg: leanMassKg ?? this.leanMassKg,
      fatMassKg: fatMassKg ?? this.fatMassKg,
    );
  }
}

/// Manual Hive type adapter for [WeightEntry].
class WeightEntryAdapter extends TypeAdapter<WeightEntry> {
  @override
  final int typeId = 2;

  @override
  WeightEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightEntry(
      id: fields[0] as String,
      weightKg: fields[1] as double,
      date: fields[2] as DateTime,
      note: fields[3] as String?,
      waistCm: fields[4] as double?,
      neckCm: fields[5] as double?,
      hipCm: fields[6] as double?,
      bodyFatPercentage: fields[7] as double?,
      bmi: fields[8] as double?,
      leanMassKg: fields[9] as double?,
      fatMassKg: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, WeightEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weightKg)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.waistCm)
      ..writeByte(5)
      ..write(obj.neckCm)
      ..writeByte(6)
      ..write(obj.hipCm)
      ..writeByte(7)
      ..write(obj.bodyFatPercentage)
      ..writeByte(8)
      ..write(obj.bmi)
      ..writeByte(9)
      ..write(obj.leanMassKg)
      ..writeByte(10)
      ..write(obj.fatMassKg);
  }
}
