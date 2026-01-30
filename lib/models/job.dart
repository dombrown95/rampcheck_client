enum JobStatus {
  open,       // open and not yet started
  inProgress, // work has started
  onHold,     // temporarily paused
  completed,  // work completed
}

enum SyncStatus {
  clean,     // local matches server
  pending,   // local changes not yet synced
  syncing,   // currently syncing
  failed,    // last sync attempt failed
}

String _enumToString(Object e) => e.toString().split('.').last;

T _enumFromString<T>(List<T> values, String value, T fallback) {
  for (final v in values) {
    if (_enumToString(v as Object) == value) return v;
  }
  return fallback;
}

class Job {
  final String id;
  final String title;
  final String aircraftRef;

  final JobStatus status;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const Job({
    required this.id,
    required this.title,
    required this.aircraftRef,
    required this.status,
    required this.updatedAt,
    required this.syncStatus,
  });

  Job copyWith({
    String? id,
    String? title,
    String? aircraftRef,
    JobStatus? status,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      aircraftRef: aircraftRef ?? this.aircraftRef,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'aircraftRef': aircraftRef,
        'status': _enumToString(status),
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': _enumToString(syncStatus),
      };

  factory Job.fromJson(Map<String, Object?> json) {
    final statusStr = (json['status'] as String?) ?? 'open';
    final syncStr = (json['syncStatus'] as String?) ?? 'pending';
    final updatedAtStr = json['updatedAt'] as String?;

    return Job(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      aircraftRef: (json['aircraftRef'] as String?) ?? '',
      status: _enumFromString(JobStatus.values, statusStr, JobStatus.open),
      updatedAt: updatedAtStr == null ? DateTime.now() : DateTime.parse(updatedAtStr),
      syncStatus: _enumFromString(SyncStatus.values, syncStr, SyncStatus.pending),
    );
  }
}