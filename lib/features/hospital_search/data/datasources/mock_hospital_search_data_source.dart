import '../../domain/entities/accepted_hospital.dart';
import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';

class MockHospitalSearchDataSource {
  final Set<String> _cancelledRequestIds = <String>{};

  Future<HospitalSearchProgress> getProgress(
    HospitalSearchSession session,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final int elapsedSeconds = DateTime.now()
        .difference(session.startedAt)
        .inSeconds
        .clamp(0, 86400)
        .toInt();
    final int expansionCount =
        elapsedSeconds ~/ session.expansionIntervalSeconds;
    final int currentRadiusKm =
        (session.initialRadiusKm + expansionCount * session.radiusStepKm)
            .clamp(session.initialRadiusKm, session.maximumRadiusKm)
            .toInt();

    return HospitalSearchProgress(
      requestId: session.requestId,
      currentRadiusKm: currentRadiusKm,
      elapsedSeconds: elapsedSeconds,
      acceptedHospitals: elapsedSeconds < 5
          ? const <AcceptedHospital>[]
          : <AcceptedHospital>[
              AcceptedHospital(
                offerId: 'OFFER-MOCK-HANYANG',
                name: '한양대학교병원',
                address: '서울 성동구 왕십리로 222-1',
                emergencyRoomPhone: '02-2290-8119',
                distanceMeters: 8400,
                etaMinutes: 18,
                acceptedAt: session.startedAt.add(const Duration(seconds: 5)),
              ),
            ],
    );
  }

  Future<void> selectDestination(String requestId, String offerId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<void> cancelRequest(
    String requestId,
    TransportCancellationReason reason,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _cancelledRequestIds.add('$requestId:${reason.apiValue}');
  }
}
