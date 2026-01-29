import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../models/attachment.dart';
import '../../models/inspection_item.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.store,
    required this.jobId,
    required this.jobTitle,
    required this.aircraftRef,
  });

  final LocalStore store;
  final String jobId;
  final String jobTitle;
  final String aircraftRef;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<List<InspectionItem>> _itemsFuture;
  late Future<List<Attachment>> _attachmentsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
    _attachmentsFuture = _loadAttachments();
  }

  Future<List<InspectionItem>> _loadItems() async {
    await widget.store.ensureDefaultChecklist(widget.jobId);
    return widget.store.getInspectionItemsForJob(widget.jobId);
  }

  Future<List<Attachment>> _loadAttachments() async {
    return widget.store.getAttachmentsForJob(widget.jobId);
  }

  Future<void> _refresh() async {
    setState(() {
      _itemsFuture = _loadItems();
      _attachmentsFuture = _loadAttachments();
    });
  }

  // Sets card tint to green for pass, red for fail, none for N/A.
  Color? _cardTint(InspectionResult result) {
    return switch (result) {
      InspectionResult.pass => Colors.green.withOpacity(0.20),
      InspectionResult.fail => Colors.red.withOpacity(0.20),
      InspectionResult.na => null,
    };
  }

  // Sets colour for results and icons.
  Color _resultColor(InspectionResult result) {
    return switch (result) {
      InspectionResult.pass => Colors.green,
      InspectionResult.fail => Colors.red,
      InspectionResult.na => Colors.grey,
    };
  }

  // Sets icon for results.
  IconData _resultIcon(InspectionResult result) {
    return switch (result) {
      InspectionResult.pass => Icons.check_circle_outline,
      InspectionResult.fail => Icons.cancel_outlined,
      InspectionResult.na => Icons.help_outline,
    };
  }

  // Sets label for results.
  String _resultLabel(InspectionResult result) {
    return switch (result) {
      InspectionResult.pass => 'Pass',
      InspectionResult.fail => 'Fail',
      InspectionResult.na => 'N/A',
    };
  }

  // ---------- Inspection edit dialog ----------

  Future<void> _editItem(InspectionItem item) async {
    InspectionResult selected = item.result;
    final notesController = TextEditingController(text: item.notes);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<InspectionResult>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Result'),
                items: const [
                  DropdownMenuItem(
                    value: InspectionResult.pass,
                    child: Text('Pass'),
                  ),
                  DropdownMenuItem(
                    value: InspectionResult.fail,
                    child: Text('Fail'),
                  ),
                  DropdownMenuItem(
                    value: InspectionResult.na,
                    child: Text('N/A'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) selected = v;
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final updated = item.copyWith(
      result: selected,
      notes: notesController.text,
      updatedAt: DateTime.now(),
    );

    await widget.store.upsertInspectionItem(updated);
    await _refresh();
  }

  // ---------- Attachments ----------

  Future<void> _addAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file path.')),
      );
      return;
    }

    final now = DateTime.now();
    final attachment = Attachment(
      id: 'att-${now.microsecondsSinceEpoch}',
      jobId: widget.jobId,
      localPath: path,
      fileName: file.name,
      mimeType: file.extension == null
          ? 'application/octet-stream'
          : _mimeFromExtension(file.extension!),
      uploaded: false,
      updatedAt: now,
    );

    await widget.store.upsertAttachment(attachment);
    await _refresh();
  }

  String _mimeFromExtension(String ext) {
    final e = ext.toLowerCase();
    return switch (e) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'json' => 'application/json',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _deleteAttachment(Attachment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text('Remove "${a.fileName}" from this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.store.deleteAttachment(a.id);
    await _refresh();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.jobTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.aircraftRef),
            const SizedBox(height: 16),

            // Attachments header + add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attachments',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: FutureBuilder<List<Attachment>>(
                future: _attachmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error loading attachments: ${snapshot.error}');
                  }

                  final attachments = snapshot.data ?? [];
                  if (attachments.isEmpty) {
                    return const Center(child: Text('No attachments yet.'));
                  }

                  return ListView.separated(
                    itemCount: attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final a = attachments[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(a.fileName),
                          subtitle: Text(a.uploaded ? 'Uploaded' : 'Local only'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteAttachment(a),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'Inspection items',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<InspectionItem>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No inspection items.'));
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final color = _resultColor(item.result);

                        return Card(
                          color: _cardTint(item.result),
                          child: ListTile(
                            leading: Icon(_resultIcon(item.result), color: color),
                            title: Text(item.label),
                            subtitle: Text(
                              _resultLabel(item.result),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _editItem(item),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}