import '../../models/attachment.dart';
import '../../models/inspection_item.dart';
import '../../models/job.dart';

abstract class LocalStoreContract {
  Future<List<Job>> getJobs();
  Future<void> upsertJob(Job job);

  Future<List<InspectionItem>> getInspectionItemsForJob(String jobId);
  Future<List<Attachment>> getAttachmentsForJob(String jobId);
}