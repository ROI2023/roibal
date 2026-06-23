import 'package:flutter/material.dart';

/// Icon choices available when creating a category, keyed by the
/// `icon_name` value stored in `public.categories.icon_name`.
const categoryIconOptions = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'receipt': Icons.receipt,
  'local_play': Icons.local_play,
  'trending_up': Icons.trending_up,
  'shopping_bag': Icons.shopping_bag,
  'home': Icons.home,
  'fitness_center': Icons.fitness_center,
  'pets': Icons.pets,
  'school': Icons.school,
  'flight': Icons.flight,
  'medical_services': Icons.medical_services,
  'sports_esports': Icons.sports_esports,
  'savings': Icons.savings,
  'percent': Icons.percent,
  'help_outline': Icons.help_outline,
};

IconData categoryIconFor(String? iconName) =>
    categoryIconOptions[iconName] ?? Icons.help_outline;
