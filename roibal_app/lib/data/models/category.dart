enum CategoryType { expense, income }

CategoryType categoryTypeFromString(String value) {
  switch (value) {
    case 'expense':
      return CategoryType.expense;
    case 'income':
      return CategoryType.income;
    default:
      throw ArgumentError('Unknown category type: $value');
  }
}

class Category {
  final String id;
  final String? userId;
  final String name;
  final String iconName;
  final CategoryType type;
  final double? budgetAmount;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconName,
    required this.type,
    this.budgetAmount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      type: categoryTypeFromString(json['type'] as String),
      budgetAmount: (json['budget_amount'] as num?)?.toDouble(),
    );
  }
}
