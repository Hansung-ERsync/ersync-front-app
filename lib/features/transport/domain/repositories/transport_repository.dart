import '../entities/in_transit_vital_update.dart';
import '../entities/recent_transport.dart';
import '../entities/transport_session.dart';

abstract interface class TransportRepository {
  Future<void> addVitalUpdate(String requestId, InTransitVitalUpdate update);

  Future<void> requestHandoff(TransportSession session);

  Future<List<RecentTransport>> getRecentTransports();

  Stream<List<RecentTransport>> watchRecentTransports();
}
