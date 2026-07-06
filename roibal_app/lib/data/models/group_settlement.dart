import 'group_member.dart';

enum GroupSettlementStatus { suggested, confirmed }

GroupSettlementStatus _statusFromString(String v) => switch (v) {
      'suggested' => GroupSettlementStatus.suggested,
      'confirmed' => GroupSettlementStatus.confirmed,
      _ => throw ArgumentError('Unknown settlement status: $v'),
    };

class GroupSettlement {
  final String id;
  final String eventId;
  final String fromMemberId;
  final GroupMember? fromMember;
  final String toMemberId;
  final GroupMember? toMember;
  final String currency;
  final double amount;
  final bool isCrossCurrencyNet;
  final double? exchangeRateUsed;
  final GroupSettlementStatus status;
  final DateTime? fromConfirmedAt;
  final String? fromPersonalTransactionId;
  final DateTime? toConfirmedAt;
  final String? toPersonalTransactionId;
  final DateTime? confirmedAt;
  final DateTime createdAt;

  const GroupSettlement({
    required this.id,
    required this.eventId,
    required this.fromMemberId,
    this.fromMember,
    required this.toMemberId,
    this.toMember,
    required this.currency,
    required this.amount,
    required this.isCrossCurrencyNet,
    this.exchangeRateUsed,
    required this.status,
    this.fromConfirmedAt,
    this.fromPersonalTransactionId,
    this.toConfirmedAt,
    this.toPersonalTransactionId,
    this.confirmedAt,
    required this.createdAt,
  });

  bool get isFullyConfirmed => fromConfirmedAt != null && toConfirmedAt != null;

  factory GroupSettlement.fromJson(Map<String, dynamic> json) {
    final fromJson = json['from_member'] as Map<String, dynamic>?;
    final toJson = json['to_member'] as Map<String, dynamic>?;
    return GroupSettlement(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      fromMemberId: json['from_member_id'] as String,
      fromMember: fromJson != null ? GroupMember.fromJson(fromJson) : null,
      toMemberId: json['to_member_id'] as String,
      toMember: toJson != null ? GroupMember.fromJson(toJson) : null,
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
      isCrossCurrencyNet: json['is_cross_currency_net'] as bool? ?? false,
      exchangeRateUsed: json['exchange_rate_used'] != null
          ? (json['exchange_rate_used'] as num).toDouble()
          : null,
      status: _statusFromString(json['status'] as String),
      fromConfirmedAt: json['from_confirmed_at'] != null
          ? DateTime.parse(json['from_confirmed_at'] as String)
          : null,
      fromPersonalTransactionId: json['from_personal_transaction_id'] as String?,
      toConfirmedAt: json['to_confirmed_at'] != null
          ? DateTime.parse(json['to_confirmed_at'] as String)
          : null,
      toPersonalTransactionId: json['to_personal_transaction_id'] as String?,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
