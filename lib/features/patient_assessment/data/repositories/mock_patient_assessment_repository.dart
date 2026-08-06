import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';
import '../../domain/repositories/patient_assessment_repository.dart';
import '../datasources/mock_patient_assessment_data_source.dart';

class MockPatientAssessmentRepository implements PatientAssessmentRepository {
  const MockPatientAssessmentRepository(this._dataSource);

  final MockPatientAssessmentDataSource _dataSource;

  @override
  Future<PatientAssessmentDraft> loadDraft() => _dataSource.loadDraft();

  @override
  Future<void> saveDraft(PatientAssessmentDraft draft) {
    return _dataSource.saveDraft(draft);
  }

  @override
  Future<void> clearDraft() {
    return _dataSource.clearDraft();
  }

  @override
  Future<TransferRequestReceipt> submit(PatientAssessmentDraft draft) {
    return _dataSource.submit(draft);
  }
}
