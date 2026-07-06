import 'group_member.dart';

class GroupPartialPayment {
  final String id;
  final String eventId;
  final String fromMemberId;
  final GroupMember? fromMember;
  final String toMemberId;
  final GroupMember? toMember;
  final String currency;
  final double amount;
  final String? description;
  final DateTime paymentDate;
  final DateTime? fromConfirmedAt;
  final String? fromPersonalTransactionId;
  final DateTime? toConfirmedAt;
  final String? toPersonalTransactionId;
  final DateTime createdAt;

  const GroupPartialPayment({
    required this.id,
    required this.eventId,
    required this.fromMemberId,
    this.fromMember,
    required this.toMemberId,
    this.toMember,
    required this.currency,
    required this.amount,
    this.description,
    required this.paymentDate,
    this.fromConfirmedAt,
    this.fromPersonalTransactionId,
    this.toConfirmedAt,
    this.toPersonalTransactionId,
    required this.createdAt,
  });

  bool get isFullyConfirmed => fromConfirmedAt != null && toConfirmedAt != null;

  factory GroupPartialPayment.fromJson(Map<String, dynamic> json) {
    final fromJson = json['from_member'] as Map<String, dynamic>?;
    final toJson = json['to_member'] as Map<String, dynamic>?;
    return GroupPartialPayment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      fromMemberId: json['from_member_id'] as String,
      fromMember: fromJson != null ? GroupMember.fromJson(fromJson) : null,
      toMemberId: json['to_member_id'] as String,
      toMember: toJson != null ? GroupMember.fromJson(toJson) : null,
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      fromConfirmedAt: json['from_confirmed_at'] != null
          ? DateTime.parse(json['from_confirmed_at'] as String)
          : null,
      fromPersonalTransactionId: json['from_personal_transaction_id'] as String?,
      toConfirmedAt: json['to_confirmed_at'] != null
          ? DateTime.parse(json['to_confirmed_at'] as String)
          : null,
      toPersonalTransactionId: json['to_personal_transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
