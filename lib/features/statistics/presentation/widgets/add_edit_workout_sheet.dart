import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/features/statistics/domain/entities/workout_log.dart';
import 'package:fast_flow/features/statistics/presentation/providers/workout_providers.dart';

class AddEditWorkoutSheet extends ConsumerStatefulWidget {
  final WorkoutLog? existingLog;

  const AddEditWorkoutSheet({super.key, this.existingLog});

  @override
  ConsumerState<AddEditWorkoutSheet> createState() => _AddEditWorkoutSheetState();
}

class _AddEditWorkoutSheetState extends ConsumerState<AddEditWorkoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;

  final List<_ExerciseInput> _exerciseInputs = [];

  static const List<String> _workoutPresets = [
    'Full Body Workout',
    'Upper Body Strength',
    'Lower Body & Legs',
    'Push Workout',
    'Pull Workout',
    'Arm & Shoulder Core',
  ];

  static const List<String> _exercisePresets = [
    'Bench Press',
    'Squat',
    'Deadlift',
    'Overhead Press',
    'Dumbbell Row',
    'Lat Pulldown',
    'Bicep Curl',
    'Tricep Pushdown',
    'Leg Press',
    'Plank',
  ];

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    _titleController = TextEditingController(text: log?.title ?? 'Full Body Workout');
    _durationController = TextEditingController(text: (log?.durationMinutes ?? 45).toString());
    _notesController = TextEditingController(text: log?.notes ?? '');
    _selectedDate = log?.date ?? DateTime.now();

    if (log != null && log.exercises.isNotEmpty) {
      for (final ex in log.exercises) {
        _exerciseInputs.add(_ExerciseInput(
          name: TextEditingController(text: ex.name),
          sets: TextEditingController(text: ex.sets.toString()),
          reps: TextEditingController(text: ex.reps.toString()),
          weight: TextEditingController(text: ex.weightKg.toString()),
          notes: TextEditingController(text: ex.notes),
        ));
      }
    } else {
      // Add initial default exercise
      _addExerciseInput(name: 'Bench Press', sets: 3, reps: 10, weight: 40.0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    for (final ex in _exerciseInputs) {
      ex.dispose();
    }
    super.dispose();
  }

  void _addExerciseInput({String name = 'Bench Press', int sets = 3, int reps = 10, double weight = 0.0}) {
    setState(() {
      _exerciseInputs.add(_ExerciseInput(
        name: TextEditingController(text: name),
        sets: TextEditingController(text: sets.toString()),
        reps: TextEditingController(text: reps.toString()),
        weight: TextEditingController(text: weight == 0.0 ? '' : weight.toString()),
        notes: TextEditingController(),
      ));
    });
  }

  void _removeExerciseInput(int index) {
    if (_exerciseInputs.length <= 1) return;
    setState(() {
      final removed = _exerciseInputs.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_exerciseInputs.isEmpty) return;

    final exercises = _exerciseInputs.map((e) {
      return ExerciseItem(
        name: e.name.text.trim().isEmpty ? 'Exercise' : e.name.text.trim(),
        sets: int.tryParse(e.sets.text.trim()) ?? 1,
        reps: int.tryParse(e.reps.text.trim()) ?? 1,
        weightKg: double.tryParse(e.weight.text.trim()) ?? 0.0,
        notes: e.notes.text.trim(),
      );
    }).toList();

    final id = widget.existingLog?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final log = WorkoutLog(
      id: id,
      title: _titleController.text.trim().isEmpty ? 'Workout Log' : _titleController.text.trim(),
      date: _selectedDate,
      durationMinutes: int.tryParse(_durationController.text.trim()) ?? 45,
      exercises: exercises,
      notes: _notesController.text.trim(),
    );

    if (widget.existingLog == null) {
      ref.read(workoutLogsProvider.notifier).addWorkoutLog(log);
    } else {
      ref.read(workoutLogsProvider.notifier).updateWorkoutLog(log);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingLog == null ? 'Log Workout' : 'Edit Workout',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    // Workout Title & Quick Presets
                    Text(
                      'Workout Name',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Upper Body Strength',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter workout title' : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _workoutPresets.map((preset) {
                        return ActionChip(
                          label: Text(preset, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _titleController.text = preset;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Date and Duration Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Workout Date',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (min)',
                              border: OutlineInputBorder(),
                              suffixText: 'min',
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Enter duration' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Exercises Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Exercises (${_exerciseInputs.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => _addExerciseInput(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Exercise'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Exercise Cards
                    ..._exerciseInputs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final input = entry.value;

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: colorScheme.primary,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextFormField(
                                      controller: input.name,
                                      decoration: const InputDecoration(
                                        hintText: 'Exercise Name (e.g. Squat)',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_exerciseInputs.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                      onPressed: () => _removeExerciseInput(index),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: 4,
                                children: _exercisePresets.take(5).map((preset) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        input.name.text = preset;
                                      });
                                    },
                                    child: Chip(
                                      label: Text(preset, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: input.sets,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Sets',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: TextFormField(
                                      controller: input.reps,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Reps',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: TextFormField(
                                      controller: input.weight,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Weight (kg)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Workout Notes (Optional)',
                        hintText: 'e.g. Great session, increased weight on bench press.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    widget.existingLog == null ? 'Save Workout Log' : 'Update Workout Log',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseInput {
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController notes;

  _ExerciseInput({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.notes,
  });

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    notes.dispose();
  }
}
