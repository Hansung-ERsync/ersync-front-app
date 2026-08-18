import '../../../hospital_search/domain/entities/hospital_search_session.dart';

class UrgentDestinationWithdrawal {
  const UrgentDestinationWithdrawal({
    required this.id,
    required this.hospitalName,
    required this.reason,
    required this.recoverySession,
  });

  final String id;
  final String hospitalName;
  final String reason;
  final HospitalSearchSession recoverySession;
}
