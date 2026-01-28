import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../models/job.dart';

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
    _jobsFuture = widget.store.getAllJobs();
  }

  Future<void> _refresh() async {
    setState(() {
      _jobsFuture = widget.store.getAllJobs();
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
              ),
              TextField(
                controller: aircraftController,
                decoration: const InputDecoration(labelText: 'Aircraft reference'),
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
                if (titleController.text.trim().isEmpty ||
                    aircraftController.text.trim().isEmpty) {
                  return;
                }
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
    final id = 'job-${now.millisecondsSinceEpoch}';

    final job = Job(
      id: id,
      title: titleController.text.trim(),
      aircraftRef: aircraftController.text.trim(),
      status: JobStatus.open,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    await widget.store.upsertJob(job);
    await _refresh();
  }

  Future<void> _deleteJob(String id) async {
    await widget.store.deleteJob(id);
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
            return Center(
              child: Text('Error loading jobs: ${snapshot.error}'),
            );
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
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text('${job.aircraftRef} • ${_statusLabel(job.status)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteJob(job.id),
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