import '../../../transport/domain/entities/recent_transport.dart';
import '../../../transport/domain/repositories/transport_repository.dart';
import '../../domain/repositories/home_repository.dart';

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository(this._transportRepository);

  final TransportRepository _transportRepository;

  @override
  Future<List<RecentTransport>> getRecentTransports() {
    return _transportRepository.getRecentTransports();
  }

  @override
  Stream<List<RecentTransport>> watchRecentTransports() {
    return _transportRepository.watchRecentTransports();
  }
}
