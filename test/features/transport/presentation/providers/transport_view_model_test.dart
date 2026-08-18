import 'dart:async';

import 'package:er_sync/core/location/device_location.dart';
import 'package:er_sync/core/location/location_providers.dart';
import 'package:er_sync/core/realtime/realtime_providers.dart';
import 'package:er_sync/core/realtime/realtime_signal.dart';
import 'package:er_sync/core/realtime/realtime_signal_source.dart';
import 'package:er_sync/features/hospital_search/domain/entities/accepted_hospital.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_response.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_progress.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_session.dart';
import 'package:er_sync/features/hospital_search/domain/repositories/hospital_search_repository.dart';
import 'package:er_sync/features/hospital_search/presentation/providers/hospital_search_view_model.dart';
import 'package:er_sync/features/transport/data/datasources/mock_transport_data_source.dart';
import 'package:er_sync/features/transport/data/repositories/mock_transport_repository.dart';
import 'package:er_sync/features/transport/domain/entities/patient_transport_summary.dart';
import 'package:er_sync/features/transport/domain/entities/transport_session.dart';
import 'package:er_sync/features/transport/presentation/providers/transport_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('현재 목적지 병원이 수락을 철회한 경우에만 긴급 고지를 만든다', () async {
    final StreamController<RealtimeSignal> signals =
        StreamController<RealtimeSignal>.broadcast();
    final MockTransportDataSource transportDataSource =
        MockTransportDataSource();
    final _MutableHospitalSearchRepository hospitalRepository =
        _MutableHospitalSearchRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        realtimeSignalSourceProvider.overrideWithValue(
          _ControlledRealtimeSignalSource(signals.stream),
        ),
        hospitalSearchRepositoryProvider.overrideWithValue(hospitalRepository),
        transportRepositoryProvider.overrideWithValue(
          MockTransportRepository(transportDataSource),
        ),
        deviceLocationServiceProvider.overrideWithValue(
          const _FakeDeviceLocationService(),
        ),
      ],
    );
    addTearDown(() async {
      container.read(transportViewModelProvider.notifier).stop();
      container.dispose();
      transportDataSource.dispose();
      await signals.close();
    });
    final TransportSession session = TransportSession(
      requestId: 'REQUEST-1',
      requestStartedAt: DateTime.now(),
      destination: AcceptedHospital(
        offerId: 'OFFER-CURRENT',
        name: '현재 목적지 병원',
        address: '서울시 중구',
        emergencyRoomPhone: '02-0000-0000',
        distanceMeters: 1000,
        etaMinutes: 5,
        acceptedAt: DateTime.now(),
      ),
      patientSummary: const PatientTransportSummary.empty(),
    );
    final TransportViewModel viewModel = container.read(
      transportViewModelProvider.notifier,
    );
    viewModel.start(session);

    hospitalRepository.progress = HospitalSearchProgress(
      requestId: session.requestId,
      currentRadiusKm: 10,
      elapsedSeconds: 30,
      currentDestinationOfferId: 'OFFER-CURRENT',
      withdrawnHospitals: <HospitalResponse>[
        HospitalResponse(
          offerId: 'OFFER-OTHER',
          name: '다른 병원',
          status: HospitalResponseStatus.acceptanceWithdrawn,
          offeredAt: DateTime.now(),
          withdrawnAt: DateTime.now(),
          withdrawalReason: 'BED_SHORTAGE',
        ),
      ],
    );
    signals.add(
      const RealtimeSignal(
        kind: RealtimeSignalKind.update,
        eventId: 'EVENT-OTHER',
        type: 'HOSPITAL_ACCEPTANCE_WITHDRAWN',
        aggregateId: 'OFFER-OTHER',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(transportViewModelProvider).urgentWithdrawal, isNull);

    hospitalRepository.progress = HospitalSearchProgress(
      requestId: session.requestId,
      currentRadiusKm: 10,
      elapsedSeconds: 31,
      currentAttemptTriggerType: 'ACCEPTANCE_WITHDRAWAL',
      withdrawnHospitals: <HospitalResponse>[
        HospitalResponse(
          offerId: 'OFFER-CURRENT',
          name: '현재 목적지 병원',
          status: HospitalResponseStatus.acceptanceWithdrawn,
          offeredAt: DateTime.now(),
          withdrawnAt: DateTime.now(),
          withdrawalReason: 'OTHER',
          withdrawalDetail: '응급 수술 발생',
        ),
      ],
    );
    signals.add(
      const RealtimeSignal(
        kind: RealtimeSignalKind.update,
        eventId: 'EVENT-CURRENT',
        type: 'HOSPITAL_ACCEPTANCE_WITHDRAWN',
        aggregateId: 'OFFER-CURRENT',
      ),
    );
    await _waitForUrgentWithdrawal(container);

    final notice = container.read(transportViewModelProvider).urgentWithdrawal;
    expect(notice, isNotNull);
    expect(notice!.hospitalName, '현재 목적지 병원');
    expect(notice.reason, '기타 · 응급 수술 발생');
    expect(notice.recoverySession.isDestinationRecovery, isTrue);
    expect(notice.recoverySession.requestId, session.requestId);
  });
}

Future<void> _waitForUrgentWithdrawal(ProviderContainer container) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (container.read(transportViewModelProvider).urgentWithdrawal == null &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _ControlledRealtimeSignalSource implements RealtimeSignalSource {
  const _ControlledRealtimeSignalSource(this._signals);

  final Stream<RealtimeSignal> _signals;

  @override
  Stream<RealtimeSignal> watchSignals() => _signals;
}

class _MutableHospitalSearchRepository implements HospitalSearchRepository {
  HospitalSearchProgress progress = const HospitalSearchProgress(
    requestId: 'REQUEST-1',
    currentRadiusKm: 10,
    elapsedSeconds: 0,
  );

  @override
  Future<HospitalSearchProgress> getProgress(
    HospitalSearchSession session,
  ) async => progress;

  @override
  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  ) async {}

  @override
  Future<void> selectDestination(
    String requestId,
    String offerId,
    String idempotencyKey,
  ) async {}
}

class _FakeDeviceLocationService implements DeviceLocationService {
  const _FakeDeviceLocationService();

  @override
  Future<DeviceLocationPoint?> getLastKnownLocation() async => null;

  @override
  Future<DeviceLocationPoint> getCurrentLocation() async => DeviceLocationPoint(
    latitude: 37.5665,
    longitude: 126.978,
    capturedAt: DateTime.now(),
  );
}
