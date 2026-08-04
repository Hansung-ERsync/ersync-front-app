import '../entities/patient_assessment_draft.dart';
import '../repositories/patient_assessment_repository.dart';

class SavePatientAssessmentDraft {
  const SavePatientAssessmentDraft(this._repository);

  final PatientAssessmentRepository _repository;

  Future<void> call(PatientAssessmentDraft draft) {
    return _repository.saveDraft(draft);
  }
}
