import '../../data/models/category.dart';

class CategorySuggestion {
  final String name;
  final String iconName;
  final CategoryType type;

  const CategorySuggestion({required this.name, required this.iconName, required this.type});
}

/// Suggested category names/icons shown when creating a new category.
/// These are not stored in the database — picking one just prefills the
/// form, since categories are always created as the user's own row.
const categorySuggestions = [
  CategorySuggestion(name: 'Comida y Almacén', iconName: 'restaurant', type: CategoryType.expense),
  CategorySuggestion(name: 'Transporte', iconName: 'directions_car', type: CategoryType.expense),
  CategorySuggestion(name: 'Servicios', iconName: 'receipt', type: CategoryType.expense),
  CategorySuggestion(
      name: 'Ocio y Entretenimiento', iconName: 'local_play', type: CategoryType.expense),
  CategorySuggestion(name: 'Inversiones', iconName: 'trending_up', type: CategoryType.expense),
  CategorySuggestion(name: 'Gastos Financieros', iconName: 'percent', type: CategoryType.expense),
  CategorySuggestion(name: 'Otros', iconName: 'help_outline', type: CategoryType.expense),
  CategorySuggestion(name: 'Salario', iconName: 'savings', type: CategoryType.income),
  CategorySuggestion(name: 'Honorarios', iconName: 'trending_up', type: CategoryType.income),
  CategorySuggestion(name: 'Otros ingresos', iconName: 'receipt', type: CategoryType.income),
];
