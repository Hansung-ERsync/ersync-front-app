import '../entities/hospital_search_progress.dart';
import '../entities/hospital_search_session.dart';
import '../repositories/hospital_search_repository.dart';

class GetHospitalSearchProgress {
  const GetHospitalSearchProgress(this._repository);

  final HospitalSearchRepository _repository;

  Future<HospitalSearchProgress> call(HospitalSearchSession session) {
    return _repository.getProgress(session);
  }
}
