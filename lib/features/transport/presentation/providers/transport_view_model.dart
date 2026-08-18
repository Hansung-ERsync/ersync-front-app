import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_transport_data_source.dart';
import '../../data/repositories/mock_transport_repository.dart';
import '../../data/repositories/api_transport_repository.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/idempotency/idempotency_providers.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/realtime_signal.dart';
import '../../../hospital_search/domain/entities/hospital_search_session.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';
import '../../../hospital_search/presentation/providers/hospital_search_view_model.dart';
import '../../domain/entities/in_transit_clinical_updates.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/entities/transport_location_update.dart';
import '../../domain/entities/urgent_destination_withdrawal.dart';
import '../../domain/repositories/transport_repository.dart';
import '../../domain/usecases/add_in_transit_vital_update.dart';
import '../../domain/usecases/request_handoff.dart';

final Provider<MockTransportDataSource> mockTransportDataSourceProvider =
    Provider<MockTransportDataSource>((Ref ref) {
      final MockTransportDataSource dataSource = MockTransportDataSource();
      ref.onDispose(dataSource.dispose);
      return dataSource;
    });

final Provider<TransportRepository> transportRepositoryProvider =
    Provider<TransportRepository>(
      (Ref ref) =>
          MockTransportRepository(ref.watch(mockTransportDataSourceProvider)),
    );

final Provider<TransportRepository> apiTransportRepositoryProvider =
    Provider<TransportRepository>(
      (Ref ref) => ApiTransportRepository(ref.watch(dioProvider)),
    );

final Provider<AddInTransitVitalUpdate> addInTransitVitalUpdateProvider =
    Provider<AddInTransitVitalUpdate>(
      (Ref ref) =>
          AddInTransitVitalUpdate(ref.watch(transportRepositoryProvider)),
    );

final Provider<RequestHandoff> requestHandoffProvider =
    Provider<RequestHandoff>(
      (Ref ref) => RequestHandoff(ref.watch(transportRepositoryProvider)),
    );

final NotifierProvider<TransportViewModel, TransportViewState>
transportViewModelProvider =
    NotifierProvider<TransportViewModel, TransportViewState>(
      TransportViewModel.new,
    );

class TransportViewModel extends Notifier<TransportViewState> {
  Timer? _timer;
  Timer? _locationTimer;
  Timer? _destinationStatusTimer;
  StreamSubscription<RealtimeSignal>? _realtimeSubscription;
  bool _isSendingLocation = false;
  bool _isCheckingDestination = false;
  bool _destinationRecheckRequested = false;
  String? _pendingWithdrawalEventId;
  final Set<String> _handledWithdrawalIds = <String>{};

  @override
  TransportViewState build() {
    ref.onDispose(_stopTimers);
    return const TransportViewState();
  }

  void start(TransportSession session) {
    _stopTimers();
    _handledWithdrawalIds.clear();
    _destinationRecheckRequested = false;
    _pendingWithdrawalEventId = null;
    state = TransportViewState(
      session: session,
      patientSummary: session.patientSummary,
      elapsedSeconds: _elapsedSeconds(session),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.session?.requestId == session.requestId) {
        state = state.copyWith(elapsedSeconds: _elapsedSeconds(session));
      }
    });
    _startLocationUpdates();
    _startDestinationMonitoring();
  }

  void _startDestinationMonitoring() {
    _destinationStatusTimer?.cancel();
    final StreamSubscription<RealtimeSignal>? oldSubscription =
        _realtimeSubscription;
    _realtimeSubscription = null;
    if (oldSubscription != null) {
      unawaited(oldSubscription.cancel());
    }
    _realtimeSubscription = ref
        .read(realtimeSignalSourceProvider)
        .watchSignals()
        .listen(_onRealtimeSignal, onError: (_, _) {});
    _destinationStatusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_checkDestinationStatus()),
    );
    unawaited(_checkDestinationStatus());
  }

  void _onRealtimeSignal(RealtimeSignal signal) {
    if (signal.type == 'HOSPITAL_ACCEPTANCE_WITHDRAWN' &&
        signal.aggregateId == state.session?.destination.offerId) {
      unawaited(_checkDestinationStatus(eventId: signal.eventId));
    }
  }

  Future<void> _checkDestinationStatus({String? eventId}) async {
    final TransportSession? session = state.session;
    if (session == null ||
        session.requestStatus != 'EN_ROUTE' ||
        state.urgentWithdrawal != null) {
      return;
    }
    if (_isCheckingDestination) {
      _destinationRecheckRequested = true;
      _pendingWithdrawalEventId ??= eventId;
      return;
    }
    _isCheckingDestination = true;
    try {
      final PatientTransportSummary summary =
          state.patientSummary ?? session.patientSummary;
      final HospitalSearchSession recoverySession = HospitalSearchSession(
        requestId: session.requestId,
        startedAt: session.requestStartedAt,
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
        patientSummary: summary,
        isDestinationRecovery: true,
      );
      final HospitalSearchProgress progress = await ref
          .read(hospitalSearchRepositoryProvider)
          .getProgress(recoverySession);
      final matchingWithdrawals = progress.withdrawnHospitals.where(
        (item) => item.offerId == session.destination.offerId,
      );
      final withdrawn = matchingWithdrawals.isEmpty
          ? null
          : matchingWithdrawals.first;
      if (progress.currentDestinationOfferId != null ||
          (!progress.isWithdrawalRecovery && withdrawn == null)) {
        return;
      }
      final String noticeId =
          eventId ??
          '${session.destination.offerId}:${withdrawn?.withdrawnAt?.microsecondsSinceEpoch ?? 'withdrawn'}';
      if (!_handledWithdrawalIds.add(noticeId)) {
        return;
      }
      pauseLocationUpdates();
      _destinationStatusTimer?.cancel();
      _destinationStatusTimer = null;
      state = state.copyWith(
        urgentWithdrawal: UrgentDestinationWithdrawal(
          id: noticeId,
          hospitalName: session.destination.name,
          reason: withdrawn?.reasonLabel ?? '병원 사정으로 수용이 어렵습니다.',
          recoverySession: recoverySession,
        ),
      );
    } catch (_) {
      // SSE는 변경 신호일 뿐이며 다음 주기 또는 앱 복귀 시 다시 권위 조회합니다.
    } finally {
      _isCheckingDestination = false;
      if (_destinationRecheckRequested && state.urgentWithdrawal == null) {
        _destinationRecheckRequested = false;
        final String? pendingEventId = _pendingWithdrawalEventId;
        _pendingWithdrawalEventId = null;
        unawaited(_checkDestinationStatus(eventId: pendingEventId));
      }
    }
  }

  void acknowledgeUrgentWithdrawal() {
    state = state.copyWith(clearUrgentWithdrawal: true);
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    final TransportSession? session = state.session;
    if (session == null || !session.canSendLocation) {
      return;
    }
    unawaited(_sendLocation());
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_sendLocation()),
    );
  }

  Future<void> _sendLocation() async {
    final TransportSession? session = state.session;
    if (session == null || !session.canSendLocation || _isSendingLocation) {
      return;
    }
    _isSendingLocation = true;
    try {
      final DeviceLocationPoint point = await ref
          .read(deviceLocationServiceProvider)
          .getCurrentLocation();
      await ref
          .read(transportRepositoryProvider)
          .updateLocation(
            session.requestId,
            TransportLocationUpdate(
              latitude: point.latitude,
              longitude: point.longitude,
              capturedAt: point.capturedAt,
            ),
            ref
                .read(idempotencyKeyGeneratorProvider)
                .create('location-${session.requestId}'),
          );
      if (state.session?.requestId == session.requestId) {
        state = state.copyWith(clearLocationError: true);
      }
    } catch (_) {
      if (state.session?.requestId == session.requestId) {
        state = state.copyWith(
          locationErrorMessage: '현재 위치 전송이 지연되고 있습니다. 위치 권한과 GPS를 확인해주세요.',
        );
      }
    } finally {
      _isSendingLocation = false;
    }
  }

  void pauseLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void resumeLocationUpdates() {
    _startLocationUpdates();
    if (_realtimeSubscription == null || _destinationStatusTimer == null) {
      _startDestinationMonitoring();
    } else {
      unawaited(_checkDestinationStatus());
    }
  }

  Future<bool> addVitalUpdate(InTransitVitalUpdate update) async {
    final TransportSession? session = state.session;
    final PatientTransportSummary? summary = state.patientSummary;
    if (session == null || summary == null || state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isSavingVitals: true, clearError: true);
    try {
      await ref.read(addInTransitVitalUpdateProvider)(
        session.requestId,
        update,
      );
      state = state.copyWith(
        isSavingVitals: false,
        patientSummary: summary.copyWithVitals(
          systolic: update.systolic,
          diastolic: update.diastolic,
          pulse: update.pulse,
          respiratoryRate: update.respiratoryRate,
          temperature: update.temperature,
          oxygenSaturation: update.oxygenSaturation,
          measuredAt: update.measuredAt,
        ),
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSavingVitals: false,
        errorMessage: '활력징후를 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> addConsciousnessUpdate(
    InTransitConsciousnessUpdate update,
  ) async {
    final TransportSession? session = state.session;
    final PatientTransportSummary? summary = state.patientSummary;
    if (session == null || summary == null || state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isSavingConsciousness: true, clearError: true);
    try {
      await ref
          .read(transportRepositoryProvider)
          .addConsciousnessUpdate(session.requestId, update);
      state = state.copyWith(
        isSavingConsciousness: false,
        patientSummary: summary.copyWithConsciousness(
          avpuLabel: update.avpu.apiValue,
        ),
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSavingConsciousness: false,
        errorMessage: '의식 상태를 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> addPreKtasUpdate(InTransitPreKtasUpdate update) async {
    final TransportSession? session = state.session;
    final PatientTransportSummary? summary = state.patientSummary;
    if (session == null || summary == null || state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isSavingPreKtas: true, clearError: true);
    try {
      await ref
          .read(transportRepositoryProvider)
          .addPreKtasUpdate(session.requestId, update);
      final String label = update.level == null
          ? '긴급 전송'
          : 'Pre-KTAS ${update.level}';
      state = state.copyWith(
        isSavingPreKtas: false,
        patientSummary: summary.copyWithPreKtas(preKtasLabel: label),
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSavingPreKtas: false,
        errorMessage: 'Pre-KTAS를 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> addTreatmentUpdate(InTransitTreatmentUpdate update) async {
    final TransportSession? session = state.session;
    if (session == null || state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isSavingTreatment: true, clearError: true);
    try {
      await ref
          .read(transportRepositoryProvider)
          .addTreatmentUpdate(session.requestId, update);
      state = state.copyWith(
        isSavingTreatment: false,
        latestTreatmentLabel:
            '${update.type.label} · ${update.attemptResult.label}',
        latestTreatmentAt: update.performedAt,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSavingTreatment: false,
        errorMessage: '처치 기록을 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> requestHandoff() async {
    final TransportSession? session = state.session;
    if (session == null ||
        state.isRequestingHandoff ||
        state.isCancelling ||
        state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isRequestingHandoff: true, clearError: true);
    try {
      await ref.read(requestHandoffProvider)(session);
      pauseLocationUpdates();
      state = state.copyWith(isRequestingHandoff: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isRequestingHandoff: false,
        errorMessage: '인계 요청을 전송하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> cancel(TransportCancellation cancellation) async {
    final TransportSession? session = state.session;
    if (session == null ||
        state.isCancelling ||
        state.isRequestingHandoff ||
        state.isSavingClinicalUpdate) {
      return false;
    }
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await ref
          .read(transportRepositoryProvider)
          .cancelRequest(session.requestId, cancellation);
      _stopTimers();
      state = state.copyWith(isCancelling: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isCancelling: false,
        errorMessage: '이송을 취소하지 못했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }

  void stop() => _stopTimers();

  void _stopTimers() {
    _timer?.cancel();
    _timer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _destinationStatusTimer?.cancel();
    _destinationStatusTimer = null;
    final StreamSubscription<RealtimeSignal>? subscription =
        _realtimeSubscription;
    _realtimeSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  int _elapsedSeconds(TransportSession session) {
    return DateTime.now()
        .difference(session.requestStartedAt)
        .inSeconds
        .clamp(0, 86400)
        .toInt();
  }
}

class TransportViewState {
  const TransportViewState({
    this.session,
    this.patientSummary,
    this.elapsedSeconds = 0,
    this.isSavingVitals = false,
    this.isSavingConsciousness = false,
    this.isSavingPreKtas = false,
    this.isSavingTreatment = false,
    this.isRequestingHandoff = false,
    this.isCancelling = false,
    this.latestTreatmentLabel,
    this.latestTreatmentAt,
    this.errorMessage,
    this.locationErrorMessage,
    this.urgentWithdrawal,
  });

  final TransportSession? session;
  final PatientTransportSummary? patientSummary;
  final int elapsedSeconds;
  final bool isSavingVitals;
  final bool isSavingConsciousness;
  final bool isSavingPreKtas;
  final bool isSavingTreatment;
  final bool isRequestingHandoff;
  final bool isCancelling;
  final String? latestTreatmentLabel;
  final DateTime? latestTreatmentAt;
  final String? errorMessage;
  final String? locationErrorMessage;
  final UrgentDestinationWithdrawal? urgentWithdrawal;

  bool get isSavingClinicalUpdate =>
      isSavingVitals ||
      isSavingConsciousness ||
      isSavingPreKtas ||
      isSavingTreatment;

  TransportViewState copyWith({
    PatientTransportSummary? patientSummary,
    int? elapsedSeconds,
    bool? isSavingVitals,
    bool? isSavingConsciousness,
    bool? isSavingPreKtas,
    bool? isSavingTreatment,
    bool? isRequestingHandoff,
    bool? isCancelling,
    String? latestTreatmentLabel,
    DateTime? latestTreatmentAt,
    String? errorMessage,
    String? locationErrorMessage,
    UrgentDestinationWithdrawal? urgentWithdrawal,
    bool clearError = false,
    bool clearLocationError = false,
    bool clearUrgentWithdrawal = false,
  }) {
    return TransportViewState(
      session: session,
      patientSummary: patientSummary ?? this.patientSummary,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isSavingVitals: isSavingVitals ?? this.isSavingVitals,
      isSavingConsciousness:
          isSavingConsciousness ?? this.isSavingConsciousness,
      isSavingPreKtas: isSavingPreKtas ?? this.isSavingPreKtas,
      isSavingTreatment: isSavingTreatment ?? this.isSavingTreatment,
      isRequestingHandoff: isRequestingHandoff ?? this.isRequestingHandoff,
      isCancelling: isCancelling ?? this.isCancelling,
      latestTreatmentLabel: latestTreatmentLabel ?? this.latestTreatmentLabel,
      latestTreatmentAt: latestTreatmentAt ?? this.latestTreatmentAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      locationErrorMessage: clearLocationError
          ? null
          : locationErrorMessage ?? this.locationErrorMessage,
      urgentWithdrawal: clearUrgentWithdrawal
          ? null
          : urgentWithdrawal ?? this.urgentWithdrawal,
    );
  }
}
