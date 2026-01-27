import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/job.dart';

class LocalStore {
  LocalStore._(this._db);
  final Database _db;

  static const _dbName = 'rampcheck.db';
  static const _dbVersion = 1;

  static const jobsTable = 'jobs';

  /// Open (or create) the database.
  static Future<LocalStore> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
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

        // Optional index for sorting/filtering later
        await db.execute('CREATE INDEX idx_jobs_updatedAt ON $jobsTable(updatedAt);');
      },
    );

    return LocalStore._(db);
  }

  Future<void> close() => _db.close();

  // CRUD Jobs

  Future<void> upsertJob(Job job) async {
    await _db.insert(
      jobsTable,
      job.toJson(), // keys match schema columns
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Job?> getJobById(String id) async {
    final rows = await _db.query(
      jobsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Job.fromJson(rows.first);
  }

  Future<List<Job>> getAllJobs({int? limit}) async {
    final rows = await _db.query(
      jobsTable,
      orderBy: 'updatedAt DESC',
      limit: limit,
    );

    return rows.map((r) => Job.fromJson(r)).toList();
  }

  Future<void> deleteJob(String id) async {
    await _db.delete(
      jobsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark as locally changed so sync engine can pick it up later.
  Future<void> markJobPending(String id) async {
    await _db.update(
      jobsTable,
      {
        'syncStatus': 'pending',
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Job>> getPendingJobs() async {
    final rows = await _db.query(
      jobsTable,
      where: 'syncStatus = ?',
      whereArgs: ['pending'],
      orderBy: 'updatedAt ASC',
    );

    return rows.map((r) => Job.fromJson(r)).toList();
  }
}