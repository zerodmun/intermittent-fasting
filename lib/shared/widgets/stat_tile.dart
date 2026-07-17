import 'package:flutter/material.dart';
import 'stat_card.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      icon: icon,
      label: label,
      value: value,
      color: color,
    );
  }
}