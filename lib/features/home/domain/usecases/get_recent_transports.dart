import '../../../transport/domain/entities/recent_transport.dart';
import '../repositories/home_repository.dart';

class GetRecentTransports {
  const GetRecentTransports(this._repository);

  final HomeRepository _repository;

  Future<List<RecentTransport>> call() {
    return _repository.getRecentTransports();
  }
}
