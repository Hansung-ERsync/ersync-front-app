import '../entities/transport_session.dart';
import '../repositories/transport_repository.dart';

class RequestHandoff {
  const RequestHandoff(this._repository);

  final TransportRepository _repository;

  Future<void> call(TransportSession session) {
    return _repository.requestHandoff(session);
  }
}
