import 'dart:async';

import 'package:er_sync/core/realtime/realtime_providers.dart';
import 'package:er_sync/core/realtime/realtime_signal.dart';
import 'package:er_sync/core/realtime/realtime_signal_source.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_progress.dart';
import 'package:er_sync/features/hospital_search/domain/entities/accepted_hospital.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_session.dart';
import 'package:er_sync/features/hospital_search/domain/repositories/hospital_search_repository.dart';
import 'package:er_sync/features/hospital_search/presentation/providers/hospital_search_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SSE 신호를 받으면 병원 탐색 REST 상태를 다시 조회한다', () async {
    final StreamController<RealtimeSignal> signals =
        StreamController<RealtimeSignal>.broadcast();
    final _RecordingHospitalSearchRepository repository =
        _RecordingHospitalSearchRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hospitalSearchRepositoryProvider.overrideWithValue(repository),
        realtimeSignalSourceProvider.overrideWithValue(
          _ControlledRealtimeSignalSource(signals.stream),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await signals.close();
    });

    final HospitalSearchViewModel viewModel = container.read(
      hospitalSearchViewModelProvider.notifier,
    );
    viewModel.start(
      HospitalSearchSession(
        requestId: 'REQUEST-1',
        startedAt: DateTime.now(),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );
    await _waitForCalls(repository, 1);

    signals.add(
      const RealtimeSignal(
        kind: RealtimeSignalKind.update,
        type: 'HOSPITAL_OFFER_RESPONDED',
        aggregateId: 'REQUEST-1',
      ),
    );
    await _waitForCalls(repository, 2);

    expect(repository.getProgressCallCount, 2);
    viewModel.stop();
  });

  test('REST에서 취소 상태를 받으면 실시간 갱신을 종료한다', () async {
    final StreamController<RealtimeSignal> signals =
        StreamController<RealtimeSignal>.broadcast();
    final _RecordingHospitalSearchRepository repository =
        _RecordingHospitalSearchRepository(
          nextProgress: const HospitalSearchProgress(
            requestId: 'REQUEST-CANCELLED',
            currentRadiusKm: 100,
            elapsedSeconds: 300,
            requestStatus: 'CANCELLED',
          ),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hospitalSearchRepositoryProvider.overrideWithValue(repository),
        realtimeSignalSourceProvider.overrideWithValue(
          _ControlledRealtimeSignalSource(signals.stream),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await signals.close();
    });

    final HospitalSearchViewModel viewModel = container.read(
      hospitalSearchViewModelProvider.notifier,
    );
    viewModel.start(
      HospitalSearchSession(
        requestId: 'REQUEST-CANCELLED',
        startedAt: DateTime.now(),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );
    await _waitForCalls(repository, 1);

    expect(container.read(hospitalSearchViewModelProvider).isCancelled, isTrue);
    signals.add(
      const RealtimeSignal(
        kind: RealtimeSignalKind.update,
        type: 'TRANSPORT_CANCELLED',
        aggregateId: 'REQUEST-CANCELLED',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repository.getProgressCallCount, 1);
  });

  test('병원 수락 후 목적지 선택 전에도 경과 타이머를 계속 증가시킨다', () async {
    final _RecordingHospitalSearchRepository repository =
        _RecordingHospitalSearchRepository(
          nextProgress: const HospitalSearchProgress(
            requestId: 'REQUEST-ACCEPTED',
            currentRadiusKm: 100,
            elapsedSeconds: 19,
            requestStatus: 'ACCEPTED_AVAILABLE',
            isElapsedRunning: true,
          ),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hospitalSearchRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final HospitalSearchViewModel viewModel = container.read(
      hospitalSearchViewModelProvider.notifier,
    );
    viewModel.start(
      HospitalSearchSession(
        requestId: 'REQUEST-ACCEPTED',
        startedAt: DateTime.now(),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );
    await _waitForCalls(repository, 1);
    expect(
      container.read(hospitalSearchViewModelProvider).progress?.elapsedSeconds,
      19,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(
      container.read(hospitalSearchViewModelProvider).progress?.elapsedSeconds,
      greaterThanOrEqualTo(20),
    );
    viewModel.stop();
  });

  test('같은 목적지 명령 재시도는 키를 유지하고 새 선택에는 새 키를 쓴다', () async {
    final _RecordingHospitalSearchRepository repository =
        _RecordingHospitalSearchRepository(failFirstDestination: true);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hospitalSearchRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final HospitalSearchViewModel viewModel = container.read(
      hospitalSearchViewModelProvider.notifier,
    );
    viewModel.start(
      HospitalSearchSession(
        requestId: 'REQUEST-DESTINATION',
        startedAt: DateTime.now(),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );
    await _waitForCalls(repository, 1);
    final AcceptedHospital hospitalA = AcceptedHospital(
      offerId: 'OFFER-A',
      name: 'A병원',
      address: '주소',
      emergencyRoomPhone: '02-0000-0001',
      distanceMeters: 1000,
      etaMinutes: 5,
      acceptedAt: DateTime.now(),
    );
    final AcceptedHospital hospitalB = AcceptedHospital(
      offerId: 'OFFER-B',
      name: 'B병원',
      address: '주소',
      emergencyRoomPhone: '02-0000-0002',
      distanceMeters: 2000,
      etaMinutes: 8,
      acceptedAt: DateTime.now(),
    );

    expect(await viewModel.selectDestination(hospitalA), isFalse);
    expect(await viewModel.selectDestination(hospitalA), isTrue);
    expect(await viewModel.selectDestination(hospitalB), isTrue);

    expect(repository.destinationKeys, hasLength(3));
    expect(repository.destinationKeys[0], repository.destinationKeys[1]);
    expect(repository.destinationKeys[2], isNot(repository.destinationKeys[1]));
  });
}

Future<void> _waitForCalls(
  _RecordingHospitalSearchRepository repository,
  int expected,
) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (repository.getProgressCallCount < expected &&
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

class _RecordingHospitalSearchRepository implements HospitalSearchRepository {
  _RecordingHospitalSearchRepository({
    this.nextProgress,
    this.failFirstDestination = false,
  });

  final HospitalSearchProgress? nextProgress;
  final bool failFirstDestination;
  int getProgressCallCount = 0;
  final List<String> destinationKeys = <String>[];

  @override
  Future<HospitalSearchProgress> getProgress(
    HospitalSearchSession session,
  ) async {
    getProgressCallCount += 1;
    return nextProgress ??
        HospitalSearchProgress(
          requestId: session.requestId,
          currentRadiusKm: session.initialRadiusKm,
          elapsedSeconds: 0,
        );
  }

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
  ) async {
    destinationKeys.add(idempotencyKey);
    if (failFirstDestination && destinationKeys.length == 1) {
      throw StateError('lost response');
    }
  }

  @override
  Future<void> retrySearch(String requestId, String idempotencyKey) async {}
}
