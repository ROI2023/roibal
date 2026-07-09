import 'category.dart';

enum MovementType { ingreso, salida, liquidacion }

class MovementItem {
  final String id;
  final DateTime date;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final CategoryType? categoryType;
  final String? accountId;
  final String? accountName;
  final String currency;
  final double totalAmount;
  final bool isTransfer;

  const MovementItem({
    required this.id,
    required this.date,
    required this.description,
    this.categoryId,
    this.categoryName,
    this.categoryType,
    this.accountId,
    this.accountName,
    required this.currency,
    required this.totalAmount,
    required this.isTransfer,
  });

  MovementType get movementType {
    if (isTransfer) return MovementType.liquidacion;
    if (categoryType == CategoryType.income) return MovementType.ingreso;
    return MovementType.salida;
  }

  double get signedAmount =>
      movementType == MovementType.ingreso ? totalAmount : -totalAmount;

  factory MovementItem.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['categories'] as Map<String, dynamic>?;
    final movements = json['transaction_movements'] as List?;
    final firstMovement =
        (movements != null && movements.isNotEmpty) ? movements.first : null;
    final accountJson =
        firstMovement?['accounts'] as Map<String, dynamic>?;

    CategoryType? catType;
    if (categoryJson != null) {
      catType = categoryJson['type'] == 'income'
          ? CategoryType.income
          : CategoryType.expense;
    }

    return MovementItem(
      id: json['id'] as String,
      date: DateTime.parse(json['transaction_date'] as String),
      description: json['description'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: categoryJson?['name'] as String?,
      categoryType: catType,
      accountId: firstMovement?['account_id'] as String?,
      accountName: accountJson?['name'] as String?,
      currency: json['currency'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      isTransfer: json['is_transfer'] as bool? ?? false,
    );
  }
}
