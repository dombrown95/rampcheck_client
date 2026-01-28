import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/job.dart';
import '../../models/inspection_item.dart';

class LocalStore {
  LocalStore._(this._db);

  static const _dbName = 'rampcheck.db';
  static const _dbVersion = 2;

  static const jobsTable = 'jobs';
  static const inspectionItemsTable = 'inspection_items';

  final Database _db;

  // ---------- OPEN ----------

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

        await db.execute(
          'CREATE INDEX idx_jobs_updatedAt ON $jobsTable(updatedAt);',
        );

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
      },
    );

    return LocalStore._(db);
  }

  // ---------- JOBS ----------

  Future<List<Job>> getJobs() async {
    final rows = await _db.query(
      jobsTable,
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => Job.fromJson(r)).toList();
  }

  Future<void> upsertJob(Job job) async {
    await _db.insert(
      jobsTable,
      job.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteJob(String id) async {
    await _db.delete(
      jobsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- INSPECTION ITEMS ----------

  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId) async {
    final rows = await _db.query(
      inspectionItemsTable,
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => InspectionItem.fromJson(r)).toList();
  }

  Future<void> upsertInspectionItem(InspectionItem item) async {
    await _db.insert(
      inspectionItemsTable,
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteInspectionItem(String id) async {
    await _db.delete(
      inspectionItemsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Checks a default checklist if none exists.
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

  // ---------- DEBUG / CLEANUP ----------

  Future<void> close() async {
    await _db.close();
  }
}
