import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../data/remote/api_client.dart';
import '../../models/job.dart';
import '../../models/session.dart';
import '../../sync/sync_engine.dart';
import 'job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({
    super.key,
    required this.store,
    required this.session,
  });

  final LocalStore store;
  final Session session;

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = widget.store.getJobs();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _jobsFuture = widget.store.getJobs();
    });
  }

  Future<void> _logout() async {
    await widget.store.clearSession();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _syncNow() async {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    final api = WarehouseApiClient(
      baseUrl: isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000',
    );

    final engine = SyncEngine(
      store: widget.store,
      api: api,
      username: widget.session.username,
      password: widget.session.password,
      role: widget.session.role,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Syncing…')));

    try {
      // Marks all pending jobs as "syncing" while the sync runs.
      await widget.store.markAllPendingJobsSyncing();

      final result = await engine.syncNow();
      if (!mounted) return;

      await _refresh();
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      // Refreshes to reflect final states (synced/failed)
      await _refresh();
    }
  }

  Future<void> _showCreateJobDialog() async {
    final titleController = TextEditingController();
    final aircraftController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Job title'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: aircraftController,
                decoration: const InputDecoration(labelText: 'Aircraft reference'),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final aircraftRef = aircraftController.text.trim();
                if (title.isEmpty || aircraftRef.isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (created != true) return;

    final now = DateTime.now();
    final job = Job(
      id: 'job-${now.millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      aircraftRef: aircraftController.text.trim(),
      status: JobStatus.open,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    await widget.store.upsertJob(job);
    await _refresh();
  }

  Future<void> _deleteJob(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text('Delete "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    await widget.store.deleteJob(job.id);
    await _refresh();
  }

  // Returns a label representing the job status.
  String _statusLabel(JobStatus status) {
    return switch (status) {
      JobStatus.open => 'Open',
      JobStatus.inProgress => 'In Progress',
      JobStatus.onHold => 'On Hold',
      JobStatus.completed => 'Completed',
    };
  }

  // Returns a label representing the sync status.
  String _syncLabel(SyncStatus status) {
    return switch (status) {
      SyncStatus.pending => 'Pending sync',
      SyncStatus.syncing => 'Syncing…',
      SyncStatus.clean => 'Synced',
      SyncStatus.failed => 'Sync failed',
    };
  }

  // Returns a color representing the sync status.
  Color _syncColor(SyncStatus status) {
    return switch (status) {
      SyncStatus.pending => Colors.orange,
      SyncStatus.syncing => Colors.blue,
      SyncStatus.clean => Colors.green,
      SyncStatus.failed => Colors.red,
    };
  }

  // Returns an icon representing the sync status.
  IconData _syncIcon(SyncStatus status) {
    return switch (status) {
      SyncStatus.pending => Icons.schedule_outlined,
      SyncStatus.syncing => Icons.sync,
      SyncStatus.clean => Icons.check_circle_outline,
      SyncStatus.failed => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipOval(
              child: Container(
                width: 36,
                height: 36,
                color: Colors.white,
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/rampcheck_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.flight_takeoff, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RampCheck — Jobs',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Sync now',
            onPressed: _syncNow,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading jobs: ${snapshot.error}'));
          }

          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs yet. Tap + to create one.'));
          }

          final groups = <JobStatus, List<Job>>{
            for (final s in JobStatus.values) s: [],
          };
          for (final job in jobs) {
            groups[job.status]?.add(job);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final status in JobStatus.values) ...[
                  if ((groups[status] ?? []).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(
                        '${_statusLabel(status)} (${groups[status]!.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    ...groups[status]!.map((job) {
                      final syncColor = _syncColor(job.syncStatus);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(job.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${job.aircraftRef} • ${_statusLabel(job.status)}'),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      _syncIcon(job.syncStatus),
                                      size: 16,
                                      color: syncColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _syncLabel(job.syncStatus),
                                      style: TextStyle(
                                        color: syncColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(
                                    store: widget.store,
                                    jobId: job.id,
                                    jobTitle: job.title,
                                    aircraftRef: job.aircraftRef,
                                  ),
                                ),
                              );
                              await _refresh();
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _deleteJob(job),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateJobDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
