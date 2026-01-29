import 'package:flutter_test/flutter_test.dart';
import 'package:rampcheck_client/sync/sync_engine.dart';
import 'package:rampcheck_client/models/job.dart';
import 'package:rampcheck_client/models/inspection_item.dart';
import 'package:rampcheck_client/models/attachment.dart';
import 'package:rampcheck_client/data/local/local_store_contract.dart';
import 'package:rampcheck_client/data/remote/api_client_contract.dart';

class FakeStore implements LocalStoreContract {
  FakeStore({
    required List<Job> jobs,
    Map<String, List<InspectionItem>>? itemsByJob,
    Map<String, List<Attachment>>? attachmentsByJob,
  })  : _jobs = List<Job>.from(jobs),
        _itemsByJob = itemsByJob ?? {},
        _attachmentsByJob = attachmentsByJob ?? {};

  final List<Job> _jobs;
  final Map<String, List<InspectionItem>> _itemsByJob;
  final Map<String, List<Attachment>> _attachmentsByJob;

  final List<Job> upsertedJobs = [];

  @override
  Future<List<Job>> getJobs() async => List<Job>.from(_jobs);

  @override
  Future<void> upsertJob(Job job) async {
    upsertedJobs.add(job);

    final idx = _jobs.indexWhere((j) => j.id == job.id);
    if (idx >= 0) {
      _jobs[idx] = job;
    } else {
      _jobs.add(job);
    }
  }

  @override
  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId) async =>
      List<InspectionItem>.from(_itemsByJob[jobId] ?? const []);

  @override
  Future<List<Attachment>> getAttachmentsForJob(String jobId) async =>
      List<Attachment>.from(_attachmentsByJob[jobId] ?? const []);
}

class FakeApi implements ApiClient {
  FakeApi({this.failCreateLog = false});

  final bool failCreateLog;

  int createLogCalls = 0;

  @override
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    // Pretend user already exists -> throw so SyncEngine falls back to login
    throw Exception('User exists');
  }

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    return {'id': 123};
  }

  @override
  Future<Map<String, dynamic>> createLog({
    required String title,
    required String description,
    required String priority,
    required String status,
    required int userId,
  }) async {
    createLogCalls++;

    if (failCreateLog) {
      throw Exception('API down');
    }

    return {'id': 999};
  }
}

void main() {
  test('syncNow marks pending jobs as clean when API succeeds', () async {
    final job = Job(
      id: 'job-1',
      title: 'Test Job',
      aircraftRef: 'BAE1',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi(failCreateLog: false);

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    final summary = await engine.syncNow();

    expect(summary.synced, 1);
    expect(summary.failed, 0);
    expect(api.createLogCalls, 1);

    final updated = (await store.getJobs()).first;
    expect(updated.syncStatus, SyncStatus.clean);
  });

  test('syncNow marks pending jobs as failed when API fails', () async {
    final job = Job(
      id: 'job-2',
      title: 'Failing Job',
      aircraftRef: 'BAE2',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi(failCreateLog: true);

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    final summary = await engine.syncNow();

    expect(summary.synced, 0);
    expect(summary.failed, 1);
    expect(api.createLogCalls, 1);
    expect(summary.errors.length, 1);

    final updated = (await store.getJobs()).first;
    expect(updated.syncStatus, SyncStatus.failed);
  });
}
