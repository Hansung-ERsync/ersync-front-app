import '../repositories/patient_assessment_repository.dart';

class ClearPatientAssessmentDraft {
  const ClearPatientAssessmentDraft(this._repository);

  final PatientAssessmentRepository _repository;

  Future<void> call() => _repository.clearDraft();
}
