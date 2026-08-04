import '../entities/patient_assessment_draft.dart';
import '../repositories/patient_assessment_repository.dart';

class LoadPatientAssessmentDraft {
  const LoadPatientAssessmentDraft(this._repository);

  final PatientAssessmentRepository _repository;

  Future<PatientAssessmentDraft> call() => _repository.loadDraft();
}
