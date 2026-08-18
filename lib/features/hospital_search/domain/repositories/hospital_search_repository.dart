import '../entities/hospital_search_progress.dart';
import '../entities/hospital_search_session.dart';

abstract interface class HospitalSearchRepository {
  Future<HospitalSearchProgress> getProgress(HospitalSearchSession session);

  Future<void> selectDestination(
    String requestId,
    String offerId,
    String idempotencyKey,
  );

  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  );
}
