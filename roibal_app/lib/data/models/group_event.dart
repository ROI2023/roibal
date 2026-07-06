enum GroupEventStatus { open, pending, balanced }

enum SplitMode { perCurrency, baseCurrency }

GroupEventStatus _statusFromString(String v) => switch (v) {
      'open' => GroupEventStatus.open,
      'pending' => GroupEventStatus.pending,
      'balanced' => GroupEventStatus.balanced,
      _ => throw ArgumentError('Unknown event status: $v'),
    };

SplitMode _splitModeFromString(String v) => switch (v) {
      'per_currency' => SplitMode.perCurrency,
      'base_currency' => SplitMode.baseCurrency,
      _ => throw ArgumentError('Unknown split mode: $v'),
    };

String _statusToString(GroupEventStatus s) => switch (s) {
      GroupEventStatus.open => 'open',
      GroupEventStatus.pending => 'pending',
      GroupEventStatus.balanced => 'balanced',
    };

String _splitModeToString(SplitMode m) => switch (m) {
      SplitMode.perCurrency => 'per_currency',
      SplitMode.baseCurrency => 'base_currency',
    };

class GroupEvent {
  final String id;
  final String createdBy;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final GroupEventStatus status;
  final SplitMode splitMode;
  final String baseCurrency;
  final DateTime createdAt;

  const GroupEvent({
    required this.id,
    required this.createdBy,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.splitMode,
    required this.baseCurrency,
    required this.createdAt,
  });

  factory GroupEvent.fromJson(Map<String, dynamic> json) => GroupEvent(
        id: json['id'] as String,
        createdBy: json['created_by'] as String,
        name: json['name'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        status: _statusFromString(json['status'] as String),
        splitMode: _splitModeFromString(json['split_mode'] as String),
        baseCurrency: json['base_currency'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'name': name,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'status': _statusToString(status),
        'split_mode': _splitModeToString(splitMode),
        'base_currency': baseCurrency,
      };
}
