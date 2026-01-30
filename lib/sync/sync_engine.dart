import '../../models/attachment.dart';
import '../../models/inspection_item.dart';
import '../../models/job.dart';
import '../data/local/local_store_contract.dart';
import '../data/remote/api_client_contract.dart';

class SyncEngine {
  SyncEngine({
    required this.store,
    required this.api,
    required this.username,
    required this.password,
    this.role = 'manager',
  });

  final LocalStoreContract store;
  final ApiClient api;

  // Credentials for the user
  final String username;
  final String password;
  final String role;

  /// Syncs all pending jobs to the API by creating /logs entries.
  Future<SyncSummary> syncNow() async {
    final jobs = await store.getJobs();

    final toSync = jobs
        .where((j) =>
            j.syncStatus == SyncStatus.pending ||
            j.syncStatus == SyncStatus.syncing)
        .toList();

    if (toSync.isEmpty) {
      return const SyncSummary(
        synced: 0,
        failed: 0,
        message: 'No pending jobs to sync.',
      );
    }

    final userId = await _ensureUserId();

    var synced = 0;
    var failed = 0;
    final errors = <String>[];

    for (final job in toSync) {
      try {
        // Marks as syncing before API call is attempted.
        await store.upsertJob(
          job.copyWith(
            syncStatus: SyncStatus.syncing,
            updatedAt: DateTime.now(),
          ),
        );

        final description = await _buildJobDescription(jobId: job.id);
        final status = _mapJobStatus(job.status);

        await api.createLog(
          title: 'RampCheck: ${job.title} (${job.aircraftRef})',
          description: description,
          priority: 'low',
          status: status,
          userId: userId,
        );

        // Mark clean if sync succeeds.
        await store.upsertJob(
          job.copyWith(
            syncStatus: SyncStatus.clean,
            updatedAt: DateTime.now(),
          ),
        );

        synced++;
      } catch (e) {
        failed++;
        errors.add('Job ${job.id}: $e');

        // Mark failed if sync fails.
        await store.upsertJob(
          job.copyWith(
            syncStatus: SyncStatus.failed,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    final msg = errors.isEmpty
        ? 'Sync complete: $synced job(s) synced.'
        : 'Sync complete: $synced synced, $failed failed.';

    return SyncSummary(
      synced: synced,
      failed: failed,
      message: msg,
      errors: errors,
    );
  }

  // ---- user id helpers ----

  int? _extractIntId(Map<String, dynamic> m) {
    dynamic v = m['id'] ?? m['user_id'];

    if (v == null && m['user'] is Map) {
      final user = (m['user'] as Map).cast<String, dynamic>();
      v = user['id'] ?? user['user_id'];
    }

    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<int> _ensureUserId() async {
    try {
      final created = await api.createUser(
        username: username,
        password: password,
        role: role,
      );
      final id = _extractIntId(created);
      if (id != null) return id;
    } catch (_) {
    }

    // Falls back to login
    final loggedIn = await api.login(username: username, password: password);
    final id = _extractIntId(loggedIn);
    if (id != null) return id;

    // Include response to enable debugging
    throw Exception('Could not determine user id. Login response: $loggedIn');
  }

  String _mapJobStatus(JobStatus s) {
    return switch (s) {
      JobStatus.open => 'open',
      JobStatus.inProgress => 'open',
      JobStatus.onHold => 'open',
      JobStatus.completed => 'closed',
    };
  }

  Future<String> _buildJobDescription({required String jobId}) async {
    final items = await store.getInspectionItemsForJob(jobId);
    final atts = await store.getAttachmentsForJob(jobId);

    final b = StringBuffer();
    b.writeln('Inspection items:');
    for (final InspectionItem i in items) {
      b.writeln(
        '- ${i.label} = ${_resultLabel(i.result)}'
        '${i.notes.trim().isEmpty ? '' : ' | notes: ${i.notes.trim()}'}',
      );
    }

    if (atts.isNotEmpty) {
      b.writeln('');
      b.writeln('Attachments:');
      for (final Attachment a in atts) {
        b.writeln('- ${a.fileName} (${a.mimeType}) [uploaded=${a.uploaded}]');
      }
    }

    return b.toString().trim();
  }

  String _resultLabel(InspectionResult r) {
    return switch (r) {
      InspectionResult.pass => 'PASS',
      InspectionResult.fail => 'FAIL',
      InspectionResult.na => 'N/A',
    };
  }
}

class SyncSummary {
  const SyncSummary({
    required this.synced,
    required this.failed,
    required this.message,
    this.errors = const [],
  });

  final int synced;
  final int failed;
  final String message;
  final List<String> errors;
}
