import 'group_member.dart';

class GroupExpense {
  final String id;
  final String eventId;
  final String paidByMemberId;
  final GroupMember? paidByMember;
  final String description;
  final String? categoryId;
  final String currency;
  final double amount;
  final DateTime expenseDate;
  final String? personalTransactionId;
  final DateTime createdAt;

  const GroupExpense({
    required this.id,
    required this.eventId,
    required this.paidByMemberId,
    this.paidByMember,
    required this.description,
    this.categoryId,
    required this.currency,
    required this.amount,
    required this.expenseDate,
    this.personalTransactionId,
    required this.createdAt,
  });

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    final memberJson = json['group_members'] as Map<String, dynamic>?;
    return GroupExpense(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      paidByMemberId: json['paid_by_member_id'] as String,
      paidByMember: memberJson != null ? GroupMember.fromJson(memberJson) : null,
      description: json['description'] as String,
      categoryId: json['category_id'] as String?,
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
      expenseDate: DateTime.parse(json['expense_date'] as String),
      personalTransactionId: json['personal_transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
