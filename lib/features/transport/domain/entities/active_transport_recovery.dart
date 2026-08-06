import '../../../hospital_search/domain/entities/hospital_search_session.dart';
import 'transport_session.dart';

class ActiveTransportRecovery {
  const ActiveTransportRecovery.search(this.searchSession)
    : transportSession = null;

  const ActiveTransportRecovery.transport(this.transportSession)
    : searchSession = null;

  final HospitalSearchSession? searchSession;
  final TransportSession? transportSession;
}
