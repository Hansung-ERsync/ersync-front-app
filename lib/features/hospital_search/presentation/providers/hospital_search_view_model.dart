import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_hospital_search_data_source.dart';
import '../../data/repositories/mock_hospital_search_repository.dart';
import '../../data/repositories/api_hospital_search_repository.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/idempotency/idempotency_providers.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/realtime_signal.dart';
import '../../../../core/realtime/realtime_signal_source.dart';
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

final Provider<HospitalSearchRepository> apiHospitalSearchRepositoryProvider =
    Provider<HospitalSearchRepository>(
      (Ref ref) => ApiHospitalSearchRepository(ref.watch(dioProvider)),
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
  static const Duration _fallbackPollingInterval = Duration(seconds: 30);
  static const Duration _eventDebounceDuration = Duration(milliseconds: 300);

  Timer? _fallbackTimer;
  Timer? _elapsedTimer;
  Timer? _eventDebounceTimer;
  StreamSubscription<RealtimeSignal>? _realtimeSubscription;
  bool _isRefreshing = false;
  String? _pendingDestinationOfferId;
  String? _pendingDestinationKey;
  String? _pendingRetryKey;

  @override
  HospitalSearchViewState build() {
    ref.onDispose(_stopRefreshChannels);
    return const HospitalSearchViewState();
  }

  void start(HospitalSearchSession session) {
    _stopRefreshChannels();
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
    _startRefreshChannels();
  }

  void pause() {
    _stopRefreshChannels();
  }

  void resume() {
    if (state.session == null ||
        state.isCancelled ||
        state.isSelectingDestination) {
      return;
    }
    _stopRefreshChannels();
    unawaited(_refresh());
    _startRefreshChannels();
  }

  void _startRefreshChannels() {
    _startElapsedTimer();
    final RealtimeSignalSource signalSource = ref.read(
      realtimeSignalSourceProvider,
    );
    _realtimeSubscription = signalSource.watchSignals().listen(
      _onRealtimeSignal,
      onError: (Object _, StackTrace _) {
        // The source reconnects automatically; fallback polling stays active.
      },
    );
    _fallbackTimer = Timer.periodic(
      _fallbackPollingInterval,
      (_) => unawaited(_refresh()),
    );
  }

  void _startElapsedTimer() {
    if (_elapsedTimer != null || state.progress?.isElapsedRunning != true) {
      return;
    }
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final HospitalSearchProgress? progress = state.progress;
      if (progress == null ||
          !progress.isElapsedRunning ||
          state.isCancelled ||
          state.isCancelling) {
        _stopElapsedTimer();
        return;
      }
      state = state.copyWith(
        progress: HospitalSearchProgress(
          requestId: progress.requestId,
          currentRadiusKm: progress.currentRadiusKm,
          elapsedSeconds: progress.elapsedSeconds + 1,
          requestStatus: progress.requestStatus,
          isElapsedRunning: progress.isElapsedRunning,
          expansionRemainingSeconds: progress.expansionRemainingSeconds == null
              ? null
              : (progress.expansionRemainingSeconds! - 1)
                    .clamp(0, 86400)
                    .toInt(),
          nextExpansionAt: progress.nextExpansionAt,
          candidateShortage: progress.candidateShortage,
          exhaustionReason: progress.exhaustionReason,
          acceptedHospitals: progress.acceptedHospitals,
        ),
      );
      if (progress.expansionRemainingSeconds == 1) {
        unawaited(_refresh());
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _onRealtimeSignal(RealtimeSignal signal) {
    if (state.session == null || state.isCancelling) {
      return;
    }
    _eventDebounceTimer?.cancel();
    _eventDebounceTimer = Timer(
      _eventDebounceDuration,
      () => unawaited(_refresh()),
    );
  }

  void _stopRefreshChannels() {
    _stopElapsedTimer();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _eventDebounceTimer?.cancel();
    _eventDebounceTimer = null;
    final StreamSubscription<RealtimeSignal>? subscription =
        _realtimeSubscription;
    _realtimeSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
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
        if (progress.isCancelled) {
          _stopRefreshChannels();
        } else if (progress.isElapsedRunning) {
          _startElapsedTimer();
        } else {
          _stopElapsedTimer();
        }
        state = state.copyWith(
          progress: progress,
          isCancelled: progress.isCancelled,
          clearError: true,
        );
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

  Future<bool> cancel(TransportCancellation cancellation) async {
    final HospitalSearchSession? session = state.session;
    if (session == null || state.isCancelling) {
      return false;
    }
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await ref.read(cancelTransportRequestProvider)(
        session.requestId,
        cancellation,
      );
      _stopRefreshChannels();
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
    if (_pendingDestinationOfferId != hospital.offerId ||
        _pendingDestinationKey == null) {
      _pendingDestinationOfferId = hospital.offerId;
      _pendingDestinationKey = ref
          .read(idempotencyKeyGeneratorProvider)
          .create('destination');
    }
    try {
      await ref.read(selectTransportDestinationProvider)(
        session.requestId,
        hospital.offerId,
        _pendingDestinationKey!,
      );
      _pendingDestinationOfferId = null;
      _pendingDestinationKey = null;
      _stopRefreshChannels();
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

  Future<bool> retrySearch() async {
    final HospitalSearchSession? session = state.session;
    if (session == null ||
        state.isRetrying ||
        state.progress?.isExhausted != true) {
      return false;
    }
    state = state.copyWith(isRetrying: true, clearError: true);
    _pendingRetryKey ??= ref
        .read(idempotencyKeyGeneratorProvider)
        .create('search-retry');
    try {
      await ref
          .read(hospitalSearchRepositoryProvider)
          .retrySearch(session.requestId, _pendingRetryKey!);
      _pendingRetryKey = null;
      await _refresh();
      state = state.copyWith(isRetrying: false, clearError: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isRetrying: false,
        errorMessage: '병원 검색을 다시 시작하지 못했습니다. 잠시 후 재시도해주세요.',
      );
      return false;
    }
  }

  void stop() {
    _stopRefreshChannels();
  }
}

class HospitalSearchViewState {
  const HospitalSearchViewState({
    this.session,
    this.progress,
    this.isCancelling = false,
    this.isCancelled = false,
    this.isSelectingDestination = false,
    this.isRetrying = false,
    this.errorMessage,
  });

  final HospitalSearchSession? session;
  final HospitalSearchProgress? progress;
  final bool isCancelling;
  final bool isCancelled;
  final bool isSelectingDestination;
  final bool isRetrying;
  final String? errorMessage;

  HospitalSearchViewState copyWith({
    HospitalSearchProgress? progress,
    bool? isCancelling,
    bool? isCancelled,
    bool? isSelectingDestination,
    bool? isRetrying,
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
      isRetrying: isRetrying ?? this.isRetrying,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
