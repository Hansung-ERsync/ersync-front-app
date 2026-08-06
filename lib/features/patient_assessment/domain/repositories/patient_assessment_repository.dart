import '../entities/patient_assessment_draft.dart';
import '../entities/transfer_request_receipt.dart';

abstract interface class PatientAssessmentRepository {
  Future<PatientAssessmentDraft> loadDraft();

  Future<void> saveDraft(PatientAssessmentDraft draft);

  Future<void> clearDraft();

  Future<TransferRequestReceipt> submit(PatientAssessmentDraft draft);
}
