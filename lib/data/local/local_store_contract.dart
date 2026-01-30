import '../../models/attachment.dart';
import '../../models/inspection_item.dart';
import '../../models/job.dart';
import '../../models/session.dart';

abstract class LocalStoreContract {
  // Jobs
  Future<List<Job>> getJobs();
  Future<void> upsertJob(Job job);
  Future<void> deleteJob(String id);

  // Inspection items
  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId);
  Future<void> upsertInspectionItem(InspectionItem item);
  Future<void> deleteInspectionItem(String id);
  Future<void> ensureDefaultChecklist(String jobId);

  // Attachments
  Future<List<Attachment>> getAttachmentsForJob(String jobId);
  Future<void> upsertAttachment(Attachment attachment);
  Future<void> deleteAttachment(String id);

  // Session
  Future<Session?> getSession();
  Future<void> saveSession(Session session);
  Future<void> clearSession();

  Future<void> close();
}