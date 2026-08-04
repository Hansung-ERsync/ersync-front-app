import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/recent_transport.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/repositories/transport_repository.dart';
import '../datasources/mock_transport_data_source.dart';

class MockTransportRepository implements TransportRepository {
  const MockTransportRepository(this._dataSource);

  final MockTransportDataSource _dataSource;

  @override
  Future<void> addVitalUpdate(String requestId, InTransitVitalUpdate update) {
    return _dataSource.addVitalUpdate(requestId, update);
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
  Stream<List<RecentTransport>> watchRecentTransports() {
    return _dataSource.watchRecentTransports();
  }
}
