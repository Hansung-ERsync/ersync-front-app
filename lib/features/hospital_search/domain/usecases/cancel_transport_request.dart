import '../entities/hospital_search_progress.dart';
import '../repositories/hospital_search_repository.dart';

class CancelTransportRequest {
  const CancelTransportRequest(this._repository);

  final HospitalSearchRepository _repository;

  Future<void> call(String requestId, TransportCancellationReason reason) {
    return _repository.cancelRequest(requestId, reason);
  }
}
