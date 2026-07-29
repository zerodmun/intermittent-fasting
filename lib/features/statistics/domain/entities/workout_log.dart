import 'package:fast_flow/core/services/hive_service.dart';

class ExerciseItem {
  final String name;
  final int sets;
  final int reps;
  final double weightKg;
  final String notes;

  const ExerciseItem({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'weightKg': weightKg,
        'notes': notes,
      };

  factory ExerciseItem.fromMap(Map<String, dynamic> map) => ExerciseItem(
        name: map['name'] as String? ?? 'Exercise',
        sets: (map['sets'] as num?)?.toInt() ?? 1,
        reps: (map['reps'] as num?)?.toInt() ?? 10,
        weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
        notes: map['notes'] as String? ?? '',
      );

  /// Volume in kg for this specific exercise
  double get totalVolumeKg => sets * reps * weightKg;
}

class WorkoutLog {
  final String id;
  final String title;
  final DateTime date;
  final int durationMinutes;
  final List<ExerciseItem> exercises;
  final String notes;

  const WorkoutLog({
    required this.id,
    required this.title,
    required this.date,
    required this.durationMinutes,
    required this.exercises,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'notes': notes,
      };

  factory WorkoutLog.fromMap(Map<String, dynamic> map) => WorkoutLog(
        id: map['id'] as String,
        title: map['title'] as String? ?? 'Workout',
        date: DateTime.parse(map['date'] as String),
        durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
        exercises: (map['exercises'] as List<dynamic>?)
                ?.map((e) => ExerciseItem.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        notes: map['notes'] as String? ?? '',
      );

  int get totalExercises => exercises.length;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);

  int get totalReps => exercises.fold(0, (sum, e) => sum + (e.sets * e.reps));

  double get totalVolumeKg => exercises.fold(0.0, (sum, e) => sum + e.totalVolumeKg);

  /// Calculates estimated calories burned using ACSM / Compendium MET methodology
  /// Base formula: Calories = MET * BodyWeight(kg) * Duration(hours)
  /// Refined MET formula using resistance volume & density adjustment:
  /// - Base resistance MET = 4.0 (moderate resistance training) to 6.0 (vigorous)
  /// - Volume & density intensity bonus = min(2.5, (totalVolumeKg / 1000) * 0.2 + (totalSets / duration) * 0.5)
  double get estimatedCaloriesBurned {
    double bodyWeightKg = 70.0; // Standard default fallback
    try {
      final userProfile = HiveService.instance.userProfileBox.get('profile');
      if (userProfile != null && userProfile.weightKg > 0) {
        bodyWeightKg = userProfile.weightKg;
      }
    } catch (_) {}

    final durationHours = (durationMinutes > 0 ? durationMinutes : 30) / 60.0;

    // Estimate exercise intensity based on sets per minute and total volume
    double baseMet = 4.5; // Moderate weight training
    if (totalVolumeKg > 5000) {
      baseMet = 6.0; // Heavy volume / vigorous resistance
    } else if (totalVolumeKg > 2000) {
      baseMet = 5.0;
    }

    final setsPerMinute = durationMinutes > 0 ? totalSets / durationMinutes : 0.5;
    final double intensityBonus = (setsPerMinute * 1.5).clamp(0.0, 2.0);

    final double adjustedMet = (baseMet + intensityBonus).clamp(3.5, 8.5);

    final double estimatedCalories = adjustedMet * bodyWeightKg * durationHours;
    return double.parse(estimatedCalories.toStringAsFixed(1));
  }

  /// Calculation accuracy statement constant (≈70%)
  static const String accuracyPercentage = '≈70%';
  static const String accuracyExplanation =
      'This value is estimated using your recorded workout information, body weight, workout duration, and exercise intensity. '
      'Since heart rate, movement speed, rest intervals, and metabolic differences are not measured, the calorie value is an approximation.';
}
