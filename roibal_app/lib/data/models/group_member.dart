enum GroupMemberStatus { invited, accepted, declined }

GroupMemberStatus _statusFromString(String v) => switch (v) {
      'invited' => GroupMemberStatus.invited,
      'accepted' => GroupMemberStatus.accepted,
      'declined' => GroupMemberStatus.declined,
      _ => throw ArgumentError('Unknown member status: $v'),
    };

class GroupMember {
  final String id;
  final String eventId;
  final String? userId;
  final String? invitedEmail;
  final String? displayName;
  final GroupMemberStatus status;
  final DateTime? joinedAt;
  final DateTime createdAt;

  const GroupMember({
    required this.id,
    required this.eventId,
    this.userId,
    this.invitedEmail,
    this.displayName,
    required this.status,
    this.joinedAt,
    required this.createdAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String?,
        invitedEmail: json['invited_email'] as String?,
        displayName: json['display_name'] as String?,
        status: _statusFromString(json['status'] as String),
        joinedAt: json['joined_at'] != null
            ? DateTime.parse(json['joined_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Nombre a mostrar en la UI.
  String get label => displayName ?? invitedEmail ?? userId ?? 'Desconocido';
}
