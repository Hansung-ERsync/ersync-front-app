import '../entities/in_transit_clinical_updates.dart';
import '../entities/in_transit_vital_update.dart';
import '../entities/recent_transport.dart';
import '../entities/transport_session.dart';
import '../entities/transport_location_update.dart';
import '../entities/active_transport_recovery.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';

abstract interface class TransportRepository {
  Future<ActiveTransportRecovery?> recoverActiveTransport();

  Future<void> addVitalUpdate(String requestId, InTransitVitalUpdate update);

  Future<void> addConsciousnessUpdate(
    String requestId,
    InTransitConsciousnessUpdate update,
  );

  Future<void> addPreKtasUpdate(
    String requestId,
    InTransitPreKtasUpdate update,
  );

  Future<void> addTreatmentUpdate(
    String requestId,
    InTransitTreatmentUpdate update,
  );

  Future<void> requestHandoff(TransportSession session);

  Future<void> updateLocation(
    String requestId,
    TransportLocationUpdate update,
    String idempotencyKey,
  );

  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  );

  Future<List<RecentTransport>> getRecentTransports();

  Stream<List<RecentTransport>> watchRecentTransports();
}
