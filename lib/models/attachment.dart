// lib/models/attachment.dart

class Attachment {
  final String id;
  final String jobId;

  /// Local file path for offline-first.
  final String localPath;

  final String fileName;
  final String mimeType;

  /// Checks if attachment has been uploaded to the server.
  final bool uploaded;

  final DateTime updatedAt;

  const Attachment({
    required this.id,
    required this.jobId,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.uploaded,
    required this.updatedAt,
  });

  Attachment copyWith({
    String? id,
    String? jobId,
    String? localPath,
    String? fileName,
    String? mimeType,
    bool? uploaded,
    DateTime? updatedAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      uploaded: uploaded ?? this.uploaded,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'jobId': jobId,
        'localPath': localPath,
        'fileName': fileName,
        'mimeType': mimeType,
        'uploaded': uploaded ? 1 : 0,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, Object?> json) {
    final updatedAtStr = json['updatedAt'] as String?;
    final uploadedVal = json['uploaded'];

    final uploaded = switch (uploadedVal) {
      true => true,
      false => false,
      1 => true,
      0 => false,
      '1' => true,
      '0' => false,
      _ => false,
    };

    return Attachment(
      id: (json['id'] as String?) ?? '',
      jobId: (json['jobId'] as String?) ?? '',
      localPath: (json['localPath'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
      uploaded: uploaded,
      updatedAt: updatedAtStr == null ? DateTime.now() : DateTime.parse(updatedAtStr),
    );
  }
}