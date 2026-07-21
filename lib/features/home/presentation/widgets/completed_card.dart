import 'package:flutter/material.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/helpers/streak_calculator.dart';
import 'package:fast_flow/shared/widgets/stat_card.dart';

class CompletedCard extends StatelessWidget {
  final StreakResult streak;

  const CompletedCard({required this.streak, super.key});

  @override
  Widget build(BuildContext context) {
    return StatCard(
      icon: Icons.check_circle_rounded,
      title: 'Completed',
      value: '${streak.totalCompleted}',
      iconColor: context.colors.completedActive,
    );
  }
}
