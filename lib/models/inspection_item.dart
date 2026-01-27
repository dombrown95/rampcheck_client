// lib/models/inspection_item.dart

enum InspectionResult {
  pass,
  fail,
  na, // not applicable
}

String _enumToString(Object e) => e.toString().split('.').last;

T _enumFromString<T>(List<T> values, String value, T fallback) {
  for (final v in values) {
    if (_enumToString(v as Object) == value) return v;
  }
  return fallback;
}

class InspectionItem {
  final String id;
  final String jobId;

  final String label;
  final InspectionResult result;
  final String notes;

  final DateTime updatedAt;

  const InspectionItem({
    required this.id,
    required this.jobId,
    required this.label,
    required this.result,
    required this.notes,
    required this.updatedAt,
  });

  InspectionItem copyWith({
    String? id,
    String? jobId,
    String? label,
    InspectionResult? result,
    String? notes,
    DateTime? updatedAt,
  }) {
    return InspectionItem(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      label: label ?? this.label,
      result: result ?? this.result,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'jobId': jobId,
        'label': label,
        'result': _enumToString(result),
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InspectionItem.fromJson(Map<String, Object?> json) {
    final resultStr = (json['result'] as String?) ?? 'na';
    final updatedAtStr = json['updatedAt'] as String?;

    return InspectionItem(
      id: (json['id'] as String?) ?? '',
      jobId: (json['jobId'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      result: _enumFromString(InspectionResult.values, resultStr, InspectionResult.na),
      notes: (json['notes'] as String?) ?? '',
      updatedAt: updatedAtStr == null ? DateTime.now() : DateTime.parse(updatedAtStr),
    );
  }
}