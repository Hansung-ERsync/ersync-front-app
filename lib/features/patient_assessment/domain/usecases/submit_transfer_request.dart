import '../entities/patient_assessment_draft.dart';
import '../entities/transfer_request_receipt.dart';
import '../repositories/patient_assessment_repository.dart';

class SubmitTransferRequest {
  const SubmitTransferRequest(this._repository);

  final PatientAssessmentRepository _repository;

  Future<TransferRequestReceipt> call(PatientAssessmentDraft draft) {
    return _repository.submit(draft);
  }
}
