import '../entities/in_transit_vital_update.dart';
import '../repositories/transport_repository.dart';

class AddInTransitVitalUpdate {
  const AddInTransitVitalUpdate(this._repository);

  final TransportRepository _repository;

  Future<void> call(String requestId, InTransitVitalUpdate update) {
    return _repository.addVitalUpdate(requestId, update);
  }
}
