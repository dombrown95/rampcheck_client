import 'package:flutter_test/flutter_test.dart';
import 'package:rampcheck_client/sync/sync_engine.dart';
import 'package:rampcheck_client/models/job.dart';
import 'package:rampcheck_client/models/inspection_item.dart';
import 'package:rampcheck_client/models/attachment.dart';
import 'package:rampcheck_client/models/session.dart';
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

  Session? _session;

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
  Future<void> deleteJob(String id) async {
    _jobs.removeWhere((j) => j.id == id);
    _itemsByJob.remove(id);
    _attachmentsByJob.remove(id);
  }

  @override
  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId) async =>
      List<InspectionItem>.from(_itemsByJob[jobId] ?? const []);

  @override
  Future<void> upsertInspectionItem(InspectionItem item) async {
    final list = _itemsByJob[item.jobId] ?? <InspectionItem>[];
    final idx = list.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    _itemsByJob[item.jobId] = list;
  }

  @override
  Future<void> deleteInspectionItem(String id) async {
    for (final key in _itemsByJob.keys) {
      _itemsByJob[key] = (_itemsByJob[key] ?? []).where((i) => i.id != id).toList();
    }
  }

  @override
  Future<void> ensureDefaultChecklist(String jobId) async {
  }

  @override
  Future<List<Attachment>> getAttachmentsForJob(String jobId) async =>
      List<Attachment>.from(_attachmentsByJob[jobId] ?? const []);

  @override
  Future<void> upsertAttachment(Attachment attachment) async {
    final list = _attachmentsByJob[attachment.jobId] ?? <Attachment>[];
    final idx = list.indexWhere((a) => a.id == attachment.id);
    if (idx >= 0) {
      list[idx] = attachment;
    } else {
      list.add(attachment);
    }
    _attachmentsByJob[attachment.jobId] = list;
  }

  @override
  Future<void> deleteAttachment(String id) async {
    for (final key in _attachmentsByJob.keys) {
      _attachmentsByJob[key] =
          (_attachmentsByJob[key] ?? []).where((a) => a.id != id).toList();
    }
  }

  @override
  Future<void> saveSession(Session session) async {
    _session = session;
  }

  @override
  Future<Session?> getSession() async => _session;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<void> close() async {
  }
}

class FakeApi implements ApiClient {
  FakeApi({
    this.failCreateLog = false,
    this.failOnCreateLogCall,
    this.createUserReturnsId,
    this.loginReturnsId = 123,
  });

  final bool failCreateLog;

  final int? failOnCreateLogCall;

  final int? createUserReturnsId;

  final int loginReturnsId;

  int createLogCalls = 0;
  int createUserCalls = 0;
  int loginCalls = 0;

  final List<String> createLogStatuses = [];
  final List<String> createLogDescriptions = [];
  final List<int> createLogUserIds = [];

  @override
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    createUserCalls++;
    if (createUserReturnsId != null) {
      return {'id': createUserReturnsId};
    }
    throw Exception('User exists');
  }

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    return {'id': loginReturnsId};
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
    createLogStatuses.add(status);
    createLogDescriptions.add(description);
    createLogUserIds.add(userId);

    if (failOnCreateLogCall != null && createLogCalls == failOnCreateLogCall) {
      throw Exception('API down');
    }
    if (failCreateLog) throw Exception('API down');

    return {'id': 999};
  }
}

void main() {
  // Tests that when the API succeeds, the job is marked as clean.
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

  // Tests that when the API fails, the job is marked as failed.
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

  // Tests that when there are no pending jobs, syncNow returns early.
  test('syncNow returns "No pending jobs" and makes no API calls when nothing to sync', () async {
    final job = Job(
      id: 'job-clean',
      title: 'Already Synced',
      aircraftRef: 'BAE3',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.clean,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi();

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    final summary = await engine.syncNow();

    expect(summary.synced, 0);
    expect(summary.failed, 0);
    expect(summary.message, 'No pending jobs to sync.');
    expect(api.createLogCalls, 0);
    expect(api.loginCalls, 0);
    expect(api.createUserCalls, 0);
  });

  // Tests that jobs with syncStatus=syncing are also included in the sync set.
  test('syncNow includes jobs with syncStatus=syncing in the sync set', () async {
    final job = Job(
      id: 'job-syncing',
      title: 'Syncing Job',
      aircraftRef: 'BAE4',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.syncing,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi();

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

  // Tests that an intermediate "syncing" state is upserted before marking clean.
  test('syncNow upserts an intermediate syncing state before marking clean', () async {
    final job = Job(
      id: 'job-intermediate',
      title: 'Intermediate Job',
      aircraftRef: 'BAE5',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi();

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    final hasSyncingUpsert = store.upsertedJobs.any(
      (j) => j.id == job.id && j.syncStatus == SyncStatus.syncing,
    );
    final hasCleanUpsert = store.upsertedJobs.any(
      (j) => j.id == job.id && j.syncStatus == SyncStatus.clean,
    );

    expect(hasSyncingUpsert, true);
    expect(hasCleanUpsert, true);
  });

  // Tests a scenario with multiple jobs where some succeed and some fail.
  test('syncNow handles multiple jobs and reports partial failures', () async {
    final job1 = Job(
      id: 'job-a',
      title: 'Job A',
      aircraftRef: 'BAE6',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final job2 = Job(
      id: 'job-b',
      title: 'Job B',
      aircraftRef: 'BAE7',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job1, job2]);

    // Fails only on the second createLog call.
    final api = FakeApi(failOnCreateLogCall: 2);

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    final summary = await engine.syncNow();

    expect(api.createLogCalls, 2);
    expect(summary.synced, 1);
    expect(summary.failed, 1);
    expect(summary.errors.length, 1);

    final jobs = await store.getJobs();
    final a = jobs.firstWhere((j) => j.id == 'job-a');
    final b = jobs.firstWhere((j) => j.id == 'job-b');

    expect(a.syncStatus, SyncStatus.clean);
    expect(b.syncStatus, SyncStatus.failed);
  });

  // Tests that syncNow maps JobStatus.completed to API status "closed".
  test('syncNow maps JobStatus.completed to API status "closed"', () async {
    final job = Job(
      id: 'job-completed',
      title: 'Completed Job',
      aircraftRef: 'BAE8',
      status: JobStatus.completed,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi();

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    expect(api.createLogCalls, 1);
    expect(api.createLogStatuses.single, 'closed');
  });

  // Tests that syncNow maps Open/In Progress/On Hold to API status "open".
  test('syncNow maps open/inProgress/onHold to API status "open"', () async {
    final jobs = <Job>[
      Job(
        id: 'job-open',
        title: 'Open Job',
        aircraftRef: 'BAE9',
        status: JobStatus.open,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      ),
      Job(
        id: 'job-inprog',
        title: 'In Progress Job',
        aircraftRef: 'BAE10',
        status: JobStatus.inProgress,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      ),
      Job(
        id: 'job-hold',
        title: 'On Hold Job',
        aircraftRef: 'BAE11',
        status: JobStatus.onHold,
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      ),
    ];

    final store = FakeStore(jobs: jobs);
    final api = FakeApi();

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    expect(api.createLogCalls, 3);
    expect(api.createLogStatuses, ['open', 'open', 'open']);
  });

  // Tests that inspection items and attachments are included in the log description.
  test('syncNow includes inspection items and attachments in the log description', () async {
    final job = Job(
      id: 'job-desc',
      title: 'Desc Job',
      aircraftRef: 'BAE12',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final items = [
      InspectionItem(
        id: 'i-1',
        jobId: job.id,
        label: 'Brakes',
        result: InspectionResult.pass,
        notes: 'Looks good',
        updatedAt: DateTime(2026, 1, 1),
      ),
      InspectionItem(
        id: 'i-2',
        jobId: job.id,
        label: 'Lights',
        result: InspectionResult.fail,
        notes: '',
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final atts = [
      Attachment(
        id: 'a-1',
        jobId: job.id,
        localPath: '/tmp/photo.png',
        fileName: 'photo.png',
        mimeType: 'image/png',
        uploaded: false,
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final store = FakeStore(
      jobs: [job],
      itemsByJob: {job.id: items},
      attachmentsByJob: {job.id: atts},
    );
    final api = FakeApi();

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    expect(api.createLogCalls, 1);
    final desc = api.createLogDescriptions.single;

    expect(desc.contains('Inspection items:'), true);
    expect(desc.contains('- Brakes = PASS | notes: Looks good'), true);
    expect(desc.contains('- Lights = FAIL'), true);

    expect(desc.contains('Attachments:'), true);
    expect(desc.contains('- photo.png (image/png) [uploaded=false]'), true);
  });

  // Tests that syncNow uses createUser id when a user clicks the create user button.
  test('syncNow uses createUser id when createUser succeeds (no login needed)', () async {
    final job = Job(
      id: 'job-userid',
      title: 'UserId Job',
      aircraftRef: 'BAE13',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi(createUserReturnsId: 777, loginReturnsId: 123);

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    expect(api.createUserCalls, 1);
    expect(api.loginCalls, 0);
    expect(api.createLogCalls, 1);
    expect(api.createLogUserIds.single, 777);
  });

  // Tests that syncNow falls back to login when createUser fails and instead uses login id.
  test('syncNow falls back to login when createUser throws, and uses login id', () async {
    final job = Job(
      id: 'job-userid-fallback',
      title: 'UserId Fallback Job',
      aircraftRef: 'BAE14',
      status: JobStatus.open,
      updatedAt: DateTime(2026, 1, 1),
      syncStatus: SyncStatus.pending,
    );

    final store = FakeStore(jobs: [job]);
    final api = FakeApi(createUserReturnsId: null, loginReturnsId: 456);

    final engine = SyncEngine(
      store: store,
      api: api,
      username: 'student_user',
      password: 'password123',
    );

    await engine.syncNow();

    expect(api.createUserCalls, 1);
    expect(api.loginCalls, 1);
    expect(api.createLogCalls, 1);
    expect(api.createLogUserIds.single, 456);
  });
}