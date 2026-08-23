import '../entities/in_transit_clinical_updates.dart';
import '../entities/in_transit_vital_update.dart';
import '../entities/recent_transport.dart';
import '../entities/transport_session.dart';
import '../entities/transport_location_update.dart';
import '../entities/active_transport_recovery.dart';
import '../entities/clinical_update_result.dart';
import '../entities/transport_location_snapshot.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';

abstract interface class TransportRepository {
  Future<ActiveTransportRecovery?> recoverActiveTransport();

  Future<ClinicalUpdateResult> addVitalUpdate(
    String requestId,
    InTransitVitalUpdate update,
  );

  Future<ClinicalUpdateResult> addConsciousnessUpdate(
    String requestId,
    InTransitConsciousnessUpdate update,
  );

  Future<ClinicalUpdateResult> addPreKtasUpdate(
    String requestId,
    InTransitPreKtasUpdate update,
  );

  Future<ClinicalUpdateResult> addTreatmentUpdate(
    String requestId,
    InTransitTreatmentUpdate update,
  );

  Future<void> requestHandoff(TransportSession session);

  Future<TransportLocationSnapshot> updateLocation(
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
