import '../repositories/hospital_search_repository.dart';

class SelectTransportDestination {
  const SelectTransportDestination(this._repository);

  final HospitalSearchRepository _repository;

  Future<void> call(String requestId, String offerId, String idempotencyKey) {
    return _repository.selectDestination(requestId, offerId, idempotencyKey);
  }
}
