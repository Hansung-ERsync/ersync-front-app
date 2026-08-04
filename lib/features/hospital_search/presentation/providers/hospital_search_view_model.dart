import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_hospital_search_data_source.dart';
import '../../data/repositories/mock_hospital_search_repository.dart';
import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';
import '../../domain/entities/accepted_hospital.dart';
import '../../domain/repositories/hospital_search_repository.dart';
import '../../domain/usecases/cancel_transport_request.dart';
import '../../domain/usecases/get_hospital_search_progress.dart';
import '../../domain/usecases/select_transport_destination.dart';

final Provider<MockHospitalSearchDataSource>
mockHospitalSearchDataSourceProvider = Provider<MockHospitalSearchDataSource>(
  (Ref ref) => MockHospitalSearchDataSource(),
);

final Provider<HospitalSearchRepository> hospitalSearchRepositoryProvider =
    Provider<HospitalSearchRepository>(
      (Ref ref) => MockHospitalSearchRepository(
        ref.watch(mockHospitalSearchDataSourceProvider),
      ),
    );

final Provider<GetHospitalSearchProgress> getHospitalSearchProgressProvider =
    Provider<GetHospitalSearchProgress>(
      (Ref ref) => GetHospitalSearchProgress(
        ref.watch(hospitalSearchRepositoryProvider),
      ),
    );

final Provider<CancelTransportRequest> cancelTransportRequestProvider =
    Provider<CancelTransportRequest>(
      (Ref ref) =>
          CancelTransportRequest(ref.watch(hospitalSearchRepositoryProvider)),
    );

final Provider<SelectTransportDestination> selectTransportDestinationProvider =
    Provider<SelectTransportDestination>(
      (Ref ref) => SelectTransportDestination(
        ref.watch(hospitalSearchRepositoryProvider),
      ),
    );

final NotifierProvider<HospitalSearchViewModel, HospitalSearchViewState>
hospitalSearchViewModelProvider =
    NotifierProvider<HospitalSearchViewModel, HospitalSearchViewState>(
      HospitalSearchViewModel.new,
    );

class HospitalSearchViewModel extends Notifier<HospitalSearchViewState> {
  Timer? _timer;
  bool _isRefreshing = false;

  @override
  HospitalSearchViewState build() {
    ref.onDispose(() => _timer?.cancel());
    return const HospitalSearchViewState();
  }

  void start(HospitalSearchSession session) {
    _timer?.cancel();
    state = HospitalSearchViewState(
      session: session,
      progress: HospitalSearchProgress(
        requestId: session.requestId,
        currentRadiusKm: session.initialRadiusKm,
        elapsedSeconds: DateTime.now()
            .difference(session.startedAt)
            .inSeconds
            .clamp(0, 86400)
            .toInt(),
      ),
    );
    unawaited(_refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    final HospitalSearchSession? session = state.session;
    if (session == null || _isRefreshing || state.isCancelling) {
      return;
    }
    _isRefreshing = true;
    try {
      final HospitalSearchProgress progress = await ref.read(
        getHospitalSearchProgressProvider,
      )(session);
      if (state.session?.requestId == session.requestId) {
        state = state.copyWith(progress: progress, clearError: true);
      }
    } catch (_) {
      if (state.session?.requestId == session.requestId) {
        state = state.copyWith(
          errorMessage: '요청 상태를 갱신하지 못했습니다. 다시 확인하고 있습니다.',
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> cancel(TransportCancellationReason reason) async {
    final HospitalSearchSession? session = state.session;
    if (session == null || state.isCancelling) {
      return false;
    }
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await ref.read(cancelTransportRequestProvider)(session.requestId, reason);
      _timer?.cancel();
      state = state.copyWith(isCancelling: false, isCancelled: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isCancelling: false,
        errorMessage: '요청을 취소하지 못했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> selectDestination(AcceptedHospital hospital) async {
    final HospitalSearchSession? session = state.session;
    if (session == null || state.isSelectingDestination) {
      return false;
    }
    state = state.copyWith(isSelectingDestination: true, clearError: true);
    try {
      await ref.read(selectTransportDestinationProvider)(
        session.requestId,
        hospital.offerId,
      );
      _timer?.cancel();
      state = state.copyWith(isSelectingDestination: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSelectingDestination: false,
        errorMessage: '목적지 병원을 선택하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  void stop() {
    _timer?.cancel();
  }
}

class HospitalSearchViewState {
  const HospitalSearchViewState({
    this.session,
    this.progress,
    this.isCancelling = false,
    this.isCancelled = false,
    this.isSelectingDestination = false,
    this.errorMessage,
  });

  final HospitalSearchSession? session;
  final HospitalSearchProgress? progress;
  final bool isCancelling;
  final bool isCancelled;
  final bool isSelectingDestination;
  final String? errorMessage;

  HospitalSearchViewState copyWith({
    HospitalSearchProgress? progress,
    bool? isCancelling,
    bool? isCancelled,
    bool? isSelectingDestination,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HospitalSearchViewState(
      session: session,
      progress: progress ?? this.progress,
      isCancelling: isCancelling ?? this.isCancelling,
      isCancelled: isCancelled ?? this.isCancelled,
      isSelectingDestination:
          isSelectingDestination ?? this.isSelectingDestination,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
