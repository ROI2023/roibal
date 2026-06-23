import 'category.dart';

class ProjectedMovement {
  final String id;
  final double amount;
  final String currency;
  final DateTime dueDate;
  final int installmentNumber;
  final int totalInstallments;
  final String description;
  final Category? category;
  final String accountName;

  const ProjectedMovement({
    required this.id,
    required this.amount,
    required this.currency,
    required this.dueDate,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.description,
    required this.category,
    required this.accountName,
  });

  factory ProjectedMovement.fromJson(Map<String, dynamic> json) {
    final transactionJson = json['transactions'] as Map<String, dynamic>?;
    final categoryJson = transactionJson?['categories'] as Map<String, dynamic>?;
    final accountJson = json['accounts'] as Map<String, dynamic>?;
    return ProjectedMovement(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      installmentNumber: json['installment_number'] as int,
      totalInstallments: json['total_installments'] as int,
      description: transactionJson?['description'] as String? ?? '',
      category: categoryJson != null ? Category.fromJson(categoryJson) : null,
      accountName: accountJson?['name'] as String? ?? '',
    );
  }
}
