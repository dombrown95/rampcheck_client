import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/job.dart';
import '../../models/inspection_item.dart';
import '../../models/attachment.dart';
import '../../models/session.dart';
import 'local_store_contract.dart';

class LocalStore implements LocalStoreContract {
  LocalStore._(this._db);

  static const _dbName = 'rampcheck.db';
  static const _dbVersion = 4;

  static const jobsTable = 'jobs';
  static const inspectionItemsTable = 'inspection_items';
  static const attachmentsTable = 'attachments';
  static const sessionTable = 'session';

  final Database _db;

  static Future<LocalStore> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbName);

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        // Jobs table
        await db.execute('''
          CREATE TABLE $jobsTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            aircraftRef TEXT NOT NULL,
            status TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncStatus TEXT NOT NULL
          );
        ''');
        await db.execute('CREATE INDEX idx_jobs_updatedAt ON $jobsTable(updatedAt);');

        // Inspection items table
        await db.execute('''
          CREATE TABLE $inspectionItemsTable (
            id TEXT PRIMARY KEY,
            jobId TEXT NOT NULL,
            label TEXT NOT NULL,
            result TEXT NOT NULL,
            notes TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          );
        ''');
        await db.execute(
          'CREATE INDEX idx_items_jobId_updatedAt ON $inspectionItemsTable(jobId, updatedAt);',
        );

        // Attachments table
        await db.execute('''
          CREATE TABLE $attachmentsTable (
            id TEXT PRIMARY KEY,
            jobId TEXT NOT NULL,
            localPath TEXT NOT NULL,
            fileName TEXT NOT NULL,
            mimeType TEXT NOT NULL,
            uploaded INTEGER NOT NULL,
            updatedAt TEXT NOT NULL
          );
        ''');
        await db.execute(
          'CREATE INDEX idx_attachments_jobId_updatedAt ON $attachmentsTable(jobId, updatedAt);',
        );

        // Session table
        await db.execute('''
          CREATE TABLE $sessionTable (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $inspectionItemsTable (
              id TEXT PRIMARY KEY,
              jobId TEXT NOT NULL,
              label TEXT NOT NULL,
              result TEXT NOT NULL,
              notes TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            );
          ''');
          await db.execute(
            'CREATE INDEX idx_items_jobId_updatedAt ON $inspectionItemsTable(jobId, updatedAt);',
          );
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE $attachmentsTable (
              id TEXT PRIMARY KEY,
              jobId TEXT NOT NULL,
              localPath TEXT NOT NULL,
              fileName TEXT NOT NULL,
              mimeType TEXT NOT NULL,
              uploaded INTEGER NOT NULL,
              updatedAt TEXT NOT NULL
            );
          ''');
          await db.execute(
            'CREATE INDEX idx_attachments_jobId_updatedAt ON $attachmentsTable(jobId, updatedAt);',
          );
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE $sessionTable (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              username TEXT NOT NULL,
              password TEXT NOT NULL,
              role TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            );
          ''');
        }
      },
    );

    return LocalStore._(db);
  }

  // ---------- JOBS ----------

  @override
  Future<List<Job>> getJobs() async {
    final rows = await _db.query(jobsTable, orderBy: 'updatedAt DESC');
    return rows.map((r) => Job.fromJson(r)).toList();
  }

  @override
  Future<void> upsertJob(Job job) async {
    await _db.insert(
      jobsTable,
      job.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteJob(String id) async {
    await _db.delete(jobsTable, where: 'id = ?', whereArgs: [id]);

    await _db.delete(inspectionItemsTable, where: 'jobId = ?', whereArgs: [id]);
    await _db.delete(attachmentsTable, where: 'jobId = ?', whereArgs: [id]);
  }

  Future<void> markAllPendingJobsSyncing() async {
    final rows = await _db.query(
      jobsTable,
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.pending.name],
    );
    if (rows.isEmpty) return;

    final now = DateTime.now().toIso8601String();

    final batch = _db.batch();
    for (final r in rows) {
      final id = r['id'] as String?;
      if (id == null) continue;
      batch.update(
        jobsTable,
        {'syncStatus': SyncStatus.syncing.name, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------- INSPECTION ITEMS ----------

  @override
  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId) async {
    final rows = await _db.query(
      inspectionItemsTable,
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => InspectionItem.fromJson(r)).toList();
  }

  @override
  Future<void> upsertInspectionItem(InspectionItem item) async {
    await _db.insert(
      inspectionItemsTable,
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteInspectionItem(String id) async {
    await _db.delete(inspectionItemsTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> ensureDefaultChecklist(String jobId) async {
    final existing = await _db.query(
      inspectionItemsTable,
      where: 'jobId = ?',
      whereArgs: [jobId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = <String>[
      'Check tyres and landing gear condition',
      'Check visible leaks (fuel/oil/hydraulic)',
      'Check pitot/static covers removed',
      'Check control surfaces unobstructed',
      'Check lights and lenses intact',
    ];

    for (final label in defaults) {
      final item = InspectionItem(
        id: 'item-${now.microsecondsSinceEpoch}-${label.hashCode}',
        jobId: jobId,
        label: label,
        result: InspectionResult.na,
        notes: '',
        updatedAt: now,
      );
      await upsertInspectionItem(item);
    }
  }

  // ---------- ATTACHMENTS ----------

  @override
  Future<List<Attachment>> getAttachmentsForJob(String jobId) async {
    final rows = await _db.query(
      attachmentsTable,
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => Attachment.fromJson(r)).toList();
  }

  @override
  Future<void> upsertAttachment(Attachment attachment) async {
    await _db.insert(
      attachmentsTable,
      attachment.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAttachment(String id) async {
    await _db.delete(attachmentsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- SESSION ----------

  @override
  Future<void> saveSession(Session session) async {
    await _db.insert(
      sessionTable,
      {
        'id': 1,
        'username': session.username,
        'password': session.password,
        'role': session.role,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Session?> getSession() async {
    final rows = await _db.query(
      sessionTable,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final r = rows.single;

    return Session(
      username: (r['username'] as String?) ?? '',
      password: (r['password'] as String?) ?? '',
      role: (r['role'] as String?) ?? 'manager',
    );
  }

  @override
  Future<void> clearSession() async {
    await _db.delete(sessionTable, where: 'id = ?', whereArgs: [1]);
  }

  // ---------- CLEANUP ----------

  @override
  Future<void> close() async {
    await _db.close();
  }
}