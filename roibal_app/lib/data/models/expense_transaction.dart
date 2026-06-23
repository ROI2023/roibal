import 'category.dart';

class ExpenseTransaction {
  final String id;
  final String userId;
  final String description;
  final String? categoryId;
  final Category? category;
  final String currency;
  final double totalAmount;
  final DateTime transactionDate;
  final bool isTransfer;

  const ExpenseTransaction({
    required this.id,
    required this.userId,
    required this.description,
    required this.categoryId,
    required this.category,
    required this.currency,
    required this.totalAmount,
    required this.transactionDate,
    required this.isTransfer,
  });

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['categories'] as Map<String, dynamic>?;
    return ExpenseTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as String?,
      category: categoryJson != null ? Category.fromJson(categoryJson) : null,
      currency: json['currency'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      isTransfer: json['is_transfer'] as bool? ?? false,
    );
  }
}
