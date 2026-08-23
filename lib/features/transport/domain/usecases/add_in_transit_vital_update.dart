import '../entities/in_transit_vital_update.dart';
import '../entities/clinical_update_result.dart';
import '../repositories/transport_repository.dart';

class AddInTransitVitalUpdate {
  const AddInTransitVitalUpdate(this._repository);

  final TransportRepository _repository;

  Future<ClinicalUpdateResult> call(
    String requestId,
    InTransitVitalUpdate update,
  ) {
    return _repository.addVitalUpdate(requestId, update);
  }
}
