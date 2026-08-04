import '../../../transport/domain/entities/recent_transport.dart';

abstract interface class HomeRepository {
  Future<List<RecentTransport>> getRecentTransports();

  Stream<List<RecentTransport>> watchRecentTransports();
}
