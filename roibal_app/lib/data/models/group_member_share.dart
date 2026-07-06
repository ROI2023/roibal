class GroupMemberShare {
  final String id;
  final String groupMemberId;
  final String currency;
  final double percentage;
  final DateTime updatedAt;

  const GroupMemberShare({
    required this.id,
    required this.groupMemberId,
    required this.currency,
    required this.percentage,
    required this.updatedAt,
  });

  factory GroupMemberShare.fromJson(Map<String, dynamic> json) => GroupMemberShare(
        id: json['id'] as String,
        groupMemberId: json['group_member_id'] as String,
        currency: json['currency'] as String,
        percentage: (json['percentage'] as num).toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
