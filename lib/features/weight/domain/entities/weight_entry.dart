import 'package:hive_ce/hive.dart';

part 'weight_entry.g.dart';

@HiveType(typeId: 4)
class WeightEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double weightKg;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  double? bodyFatPercentage;

  @HiveField(4)
  double? leanMassKg;

  @HiveField(5)
  double? fatMassKg;

  @HiveField(6)
  double? bmi;

  @HiveField(7)
  double? bmr;

  @HiveField(8)
  double? tdee;

  @HiveField(9)
  double? waistCm;

  @HiveField(10)
  double? neckCm;

  @HiveField(11)
  double? hipCm;

  @HiveField(12)
  double? chestCm;

  @HiveField(13)
  double? leftArmCm;

  @HiveField(14)
  double? rightArmCm;

  @HiveField(15)
  double? leftForearmCm;

  @HiveField(16)
  double? rightForearmCm;

  @HiveField(17)
  double? leftThighCm;

  @HiveField(18)
  double? rightThighCm;

  @HiveField(19)
  double? leftCalfCm;

  @HiveField(20)
  double? rightCalfCm;

  @HiveField(21)
  double? shoulderCm;

  @HiveField(22)
  String? note;

  @HiveField(23)
  DateTime createdAt;

  @HiveField(24)
  DateTime updatedAt;

  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.date,
    this.bodyFatPercentage,
    this.leanMassKg,
    this.fatMassKg,
    this.bmi,
    this.bmr,
    this.tdee,
    this.waistCm,
    this.neckCm,
    this.hipCm,
    this.chestCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftForearmCm,
    this.rightForearmCm,
    this.leftThighCm,
    this.rightThighCm,
    this.leftCalfCm,
    this.rightCalfCm,
    this.shoulderCm,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  WeightEntry copyWith({
    String? id,
    double? weightKg,
    DateTime? date,
    double? bodyFatPercentage,
    double? leanMassKg,
    double? fatMassKg,
    double? bmi,
    double? bmr,
    double? tdee,
    double? waistCm,
    double? neckCm,
    double? hipCm,
    double? chestCm,
    double? leftArmCm,
    double? rightArmCm,
    double? leftForearmCm,
    double? rightForearmCm,
    double? leftThighCm,
    double? rightThighCm,
    double? leftCalfCm,
    double? rightCalfCm,
    double? shoulderCm,
    String? note,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      date: date ?? this.date,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      leanMassKg: leanMassKg ?? this.leanMassKg,
      fatMassKg: fatMassKg ?? this.fatMassKg,
      bmi: bmi ?? this.bmi,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      waistCm: waistCm ?? this.waistCm,
      neckCm: neckCm ?? this.neckCm,
      hipCm: hipCm ?? this.hipCm,
      chestCm: chestCm ?? this.chestCm,
      leftArmCm: leftArmCm ?? this.leftArmCm,
      rightArmCm: rightArmCm ?? this.rightArmCm,
      leftForearmCm: leftForearmCm ?? this.leftForearmCm,
      rightForearmCm: rightForearmCm ?? this.rightForearmCm,
      leftThighCm: leftThighCm ?? this.leftThighCm,
      rightThighCm: rightThighCm ?? this.rightThighCm,
      leftCalfCm: leftCalfCm ?? this.leftCalfCm,
      rightCalfCm: rightCalfCm ?? this.rightCalfCm,
      shoulderCm: shoulderCm ?? this.shoulderCm,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}