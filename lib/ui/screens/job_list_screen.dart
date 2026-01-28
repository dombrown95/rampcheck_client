import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../models/job.dart';
import 'job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key, required this.store});
  final LocalStore store;

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
    setState(() {
      _jobsFuture = widget.store.getJobs();
    });
  }

  Future<void> _showCreateJobDialog() async {
    final titleController = TextEditingController();
    final aircraftController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final aircraftRef = aircraftController.text.trim();
                if (title.isEmpty || aircraftRef.isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

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
      builder: (context) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text('Delete "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.store.deleteJob(job.id);
    await _refresh();
  }

  String _statusLabel(JobStatus status) {
    return switch (status) {
      JobStatus.open => 'Open',
      JobStatus.inProgress => 'In progress',
      JobStatus.closed => 'Closed',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RampCheck — Jobs'),
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = jobs[index];

                return Card(
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text('${job.aircraftRef} • ${_statusLabel(job.status)}'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(
                            store: widget.store,
                            jobId: job.id,
                            jobTitle: job.title,
                            aircraftRef: job.aircraftRef,
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteJob(job),
                      tooltip: 'Delete',
                    ),
                  ),
                );
              },
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