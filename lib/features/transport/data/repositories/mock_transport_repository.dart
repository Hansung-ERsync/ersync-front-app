import '../../domain/entities/in_transit_clinical_updates.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/recent_transport.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/entities/transport_location_update.dart';
import '../../domain/entities/active_transport_recovery.dart';
import '../../domain/entities/clinical_update_result.dart';
import '../../domain/entities/transport_location_snapshot.dart';
import '../../domain/repositories/transport_repository.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';
import '../datasources/mock_transport_data_source.dart';

class MockTransportRepository implements TransportRepository {
  const MockTransportRepository(this._dataSource);

  final MockTransportDataSource _dataSource;

  @override
  Future<ActiveTransportRecovery?> recoverActiveTransport() async => null;

  @override
  Future<ClinicalUpdateResult> addVitalUpdate(
    String requestId,
    InTransitVitalUpdate update,
  ) {
    return _dataSource.addVitalUpdate(requestId, update);
  }

  @override
  Future<ClinicalUpdateResult> addConsciousnessUpdate(
    String requestId,
    InTransitConsciousnessUpdate update,
  ) {
    return _dataSource.addConsciousnessUpdate(requestId, update);
  }

  @override
  Future<ClinicalUpdateResult> addPreKtasUpdate(
    String requestId,
    InTransitPreKtasUpdate update,
  ) {
    return _dataSource.addPreKtasUpdate(requestId, update);
  }

  @override
  Future<ClinicalUpdateResult> addTreatmentUpdate(
    String requestId,
    InTransitTreatmentUpdate update,
  ) {
    return _dataSource.addTreatmentUpdate(requestId, update);
  }

  @override
  Future<List<RecentTransport>> getRecentTransports() {
    return _dataSource.getRecentTransports();
  }

  @override
  Future<void> requestHandoff(TransportSession session) {
    return _dataSource.requestHandoff(session);
  }

  @override
  Future<TransportLocationSnapshot> updateLocation(
    String requestId,
    TransportLocationUpdate update,
    String idempotencyKey,
  ) async => TransportLocationSnapshot(
    freshness: 'CURRENT',
    latitude: update.latitude,
    longitude: update.longitude,
    capturedAt: update.capturedAt,
  );

  @override
  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  ) async {}

  @override
  Stream<List<RecentTransport>> watchRecentTransports() {
    return _dataSource.watchRecentTransports();
  }
}
