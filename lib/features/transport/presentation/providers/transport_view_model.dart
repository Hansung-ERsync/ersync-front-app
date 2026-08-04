import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_transport_data_source.dart';
import '../../data/repositories/mock_transport_repository.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/transport_session.dart';
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

  @override
  TransportViewState build() {
    ref.onDispose(() => _timer?.cancel());
    return const TransportViewState();
  }

  void start(TransportSession session) {
    _timer?.cancel();
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
  }

  Future<bool> addVitalUpdate(InTransitVitalUpdate update) async {
    final TransportSession? session = state.session;
    final PatientTransportSummary? summary = state.patientSummary;
    if (session == null || summary == null || state.isSavingVitals) {
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

  Future<bool> requestHandoff() async {
    final TransportSession? session = state.session;
    if (session == null || state.isRequestingHandoff) {
      return false;
    }
    state = state.copyWith(isRequestingHandoff: true, clearError: true);
    try {
      await ref.read(requestHandoffProvider)(session);
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

  void stop() => _timer?.cancel();

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
    this.isRequestingHandoff = false,
    this.errorMessage,
  });

  final TransportSession? session;
  final PatientTransportSummary? patientSummary;
  final int elapsedSeconds;
  final bool isSavingVitals;
  final bool isRequestingHandoff;
  final String? errorMessage;

  TransportViewState copyWith({
    PatientTransportSummary? patientSummary,
    int? elapsedSeconds,
    bool? isSavingVitals,
    bool? isRequestingHandoff,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransportViewState(
      session: session,
      patientSummary: patientSummary ?? this.patientSummary,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isSavingVitals: isSavingVitals ?? this.isSavingVitals,
      isRequestingHandoff: isRequestingHandoff ?? this.isRequestingHandoff,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
