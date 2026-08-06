import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';
import '../../domain/repositories/hospital_search_repository.dart';
import '../datasources/mock_hospital_search_data_source.dart';

class MockHospitalSearchRepository implements HospitalSearchRepository {
  const MockHospitalSearchRepository(this._dataSource);

  final MockHospitalSearchDataSource _dataSource;

  @override
  Future<HospitalSearchProgress> getProgress(HospitalSearchSession session) {
    return _dataSource.getProgress(session);
  }

  @override
  Future<void> selectDestination(
    String requestId,
    String offerId,
    String idempotencyKey,
  ) {
    return _dataSource.selectDestination(requestId, offerId);
  }

  @override
  Future<void> retrySearch(String requestId, String idempotencyKey) {
    return _dataSource.retrySearch(requestId);
  }

  @override
  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  ) {
    return _dataSource.cancelRequest(requestId, cancellation);
  }
}
