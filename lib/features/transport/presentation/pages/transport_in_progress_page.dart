import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../patient_assessment/domain/entities/assessment_enums.dart';
import '../../../patient_assessment/presentation/widgets/assessment_section.dart';
import '../../../patient_assessment/presentation/widgets/clinical_time_editor.dart';
import '../../../patient_assessment/presentation/widgets/numeric_stepper_field.dart';
import '../../../patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/entities/urgent_destination_withdrawal.dart';
import '../../domain/entities/transport_location_snapshot.dart';
import '../providers/transport_view_model.dart';
import '../../../hospital_search/presentation/widgets/transport_cancellation_sheet.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';
import '../../domain/entities/in_transit_clinical_updates.dart';
import '../widgets/in_transit_clinical_update_sheets.dart';

class TransportInProgressPage extends ConsumerStatefulWidget {
  const TransportInProgressPage({super.key, required this.session});

  final TransportSession session;

  @override
  ConsumerState<TransportInProgressPage> createState() =>
      _TransportInProgressPageState();
}

class _TransportInProgressPageState
    extends ConsumerState<TransportInProgressPage>
    with WidgetsBindingObserver {
  late final TransportViewModel _viewModel;
  bool _isShowingUrgentWithdrawal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ref.read(transportViewModelProvider.notifier);
    Future<void>.microtask(() => _viewModel.start(widget.session));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _viewModel.resumeLocationUpdates();
    } else {
      _viewModel.pauseLocationUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UrgentDestinationWithdrawal?>(
      transportViewModelProvider.select(
        (TransportViewState value) => value.urgentWithdrawal,
      ),
      (
        UrgentDestinationWithdrawal? previous,
        UrgentDestinationWithdrawal? next,
      ) {
        if (next != null && next.id != previous?.id) {
          _presentUrgentWithdrawal(next);
        }
      },
    );
    final TransportViewState state = ref.watch(transportViewModelProvider);
    final PatientTransportSummary summary =
        state.patientSummary ?? widget.session.patientSummary;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: <Widget>[
                    _DestinationHospitalCard(
                      session: widget.session,
                      locationSnapshot: state.locationSnapshot,
                      onCall: _callHospital,
                      onDirections: _openDirections,
                    ),
                    const SizedBox(height: 18),
                    _PatientSummaryCard(summary: summary),
                    const SizedBox(height: 18),
                    _ClinicalUpdateCard(
                      isSavingVitals: state.isSavingVitals,
                      isSavingConsciousness: state.isSavingConsciousness,
                      isSavingPreKtas: state.isSavingPreKtas,
                      isSavingTreatment: state.isSavingTreatment,
                      latestTreatmentLabel: state.latestTreatmentLabel,
                      latestTreatmentAt: state.latestTreatmentAt,
                      onAddVitals: () => _addVitalUpdate(summary),
                      onAddConsciousness: () =>
                          _addConsciousnessUpdate(summary),
                      onAddPreKtas: () => _addPreKtasUpdate(summary),
                      onAddTreatment: _addTreatmentUpdate,
                    ),
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.statusNegative,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (state.locationErrorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('locationUpdateWarning'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.checkingBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.location_off_outlined,
                              color: AppColors.statusChecking,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.locationErrorMessage!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _HandoffBottomAction(
                isHandoffPending: widget.session.isHandoffPending,
                isSubmitting: state.isRequestingHandoff,
                isCancelling: state.isCancelling,
                isClinicalUpdateSaving: state.isSavingClinicalUpdate,
                onPressed: _requestHandoff,
                onCancel: _cancelTransport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callHospital() async {
    final String phone = widget.session.destination.emergencyRoomPhone;
    final Uri uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('전화 앱을 열 수 없습니다.')));
    }
  }

  Future<void> _openDirections() async {
    final destination = widget.session.destination;
    final double? latitude = destination.latitude;
    final double? longitude = destination.longitude;
    if (latitude == null || longitude == null) {
      return;
    }
    final Uri directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{'api': '1', 'destination': '$latitude,$longitude'},
    );
    bool opened = false;
    try {
      opened = await launchUrl(
        directionsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지도 앱을 열 수 없습니다.')));
    }
  }

  Future<void> _presentUrgentWithdrawal(
    UrgentDestinationWithdrawal notice,
  ) async {
    if (_isShowingUrgentWithdrawal || !mounted) {
      return;
    }
    _isShowingUrgentWithdrawal = true;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await HapticFeedback.heavyImpact();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.scrim,
      builder: (_) => _UrgentWithdrawalDialog(notice: notice),
    );
    if (!mounted) {
      return;
    }
    _viewModel.acknowledgeUrgentWithdrawal();
    context.goNamed(
      'hospitalSearch',
      pathParameters: <String, String>{
        'requestId': notice.recoverySession.requestId,
      },
      extra: notice.recoverySession,
    );
  }

  Future<void> _addVitalUpdate(PatientTransportSummary summary) async {
    final _VitalUpdateValues? values =
        await showModalBottomSheet<_VitalUpdateValues>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _VitalUpdateSheet(summary: summary),
        );
    if (values == null || !mounted) {
      return;
    }
    final DateTime? measuredAt = await showClinicalTimePickerSheet(
      context: context,
      title: '활력징후 측정 시간을 선택해주세요',
      description: '이송 중 새로 측정한 시각으로 기록합니다.',
      initialTime: DateTime.now(),
      sheetKey: const Key('inTransitVitalTimeSheet'),
      confirmButtonKey: const Key('confirmInTransitVitalTimeButton'),
    );
    if (measuredAt == null || !mounted) {
      return;
    }
    final bool saved = await _viewModel.addVitalUpdate(
      InTransitVitalUpdate(
        systolic: values.systolic,
        diastolic: values.diastolic,
        pulse: values.pulse,
        respiratoryRate: values.respiratoryRate,
        temperature: values.temperature,
        oxygenSaturation: values.oxygenSaturation,
        measuredAt: measuredAt,
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('활력징후를 수정했습니다. 이전 기록은 유지됩니다.')),
      );
    }
  }

  Future<void> _addConsciousnessUpdate(PatientTransportSummary summary) async {
    final InTransitConsciousnessSelection? selection =
        await showInTransitConsciousnessSheet(
          context: context,
          summary: summary,
        );
    if (selection == null || !mounted) {
      return;
    }
    final DateTime? observedAt = await showClinicalTimePickerSheet(
      context: context,
      title: '의식 관찰 시간을 선택해주세요',
      description: '이송 중 새로 관찰한 시각으로 기록합니다.',
      initialTime: DateTime.now(),
      sheetKey: const Key('inTransitConsciousnessTimeSheet'),
      confirmButtonKey: const Key('confirmInTransitConsciousnessTimeButton'),
    );
    if (observedAt == null || !mounted) {
      return;
    }
    final bool saved = await _viewModel.addConsciousnessUpdate(
      InTransitConsciousnessUpdate(
        avpu: selection.avpu,
        unassessableReason: selection.unassessableReason,
        unassessableDetail: selection.unassessableDetail,
        observedAt: observedAt,
        enteredAt: DateTime.now(),
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('의식 상태를 기록했습니다. 이전 평가는 유지됩니다.')),
      );
    }
  }

  Future<void> _addPreKtasUpdate(PatientTransportSummary summary) async {
    final InTransitPreKtasSelection? selection =
        await showInTransitPreKtasSheet(context: context, summary: summary);
    if (selection == null || !mounted) {
      return;
    }
    final DateTime? assessedAt;
    if (selection.classificationStatus == ClassificationStatus.completed) {
      assessedAt = await showClinicalTimePickerSheet(
        context: context,
        title: 'Pre-KTAS 평가 시간을 선택해주세요',
        description: '새 중증도 분류를 평가한 시각으로 기록합니다.',
        initialTime: DateTime.now(),
        sheetKey: const Key('inTransitPreKtasTimeSheet'),
        confirmButtonKey: const Key('confirmInTransitPreKtasTimeButton'),
      );
      if (assessedAt == null || !mounted) {
        return;
      }
    } else {
      assessedAt = null;
    }
    final bool saved = await _viewModel.addPreKtasUpdate(
      InTransitPreKtasUpdate(
        classificationStatus: selection.classificationStatus,
        level: selection.level,
        exceptionReason: selection.exceptionReason,
        exceptionDetail: selection.exceptionDetail,
        assessedAt: assessedAt,
        standardVersion: summary.preKtasStandardVersion,
        enteredAt: DateTime.now(),
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-KTAS를 기록했습니다. 이전 평가는 유지됩니다.')),
      );
    }
  }

  Future<void> _addTreatmentUpdate() async {
    final InTransitTreatmentSelection? selection =
        await showInTransitTreatmentSheet(context: context);
    if (selection == null || !mounted) {
      return;
    }
    final DateTime? performedAt = await showClinicalTimePickerSheet(
      context: context,
      title: '처치 시간을 선택해주세요',
      description: '처치를 시행하거나 시도한 시각으로 기록합니다.',
      initialTime: DateTime.now(),
      sheetKey: const Key('inTransitTreatmentTimeSheet'),
      confirmButtonKey: const Key('confirmInTransitTreatmentTimeButton'),
    );
    if (performedAt == null || !mounted) {
      return;
    }
    final bool saved = await _viewModel.addTreatmentUpdate(
      InTransitTreatmentUpdate(
        type: selection.type,
        attemptResult: selection.attemptResult,
        details: selection.details,
        performedAt: performedAt,
        enteredAt: DateTime.now(),
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처치 기록을 추가했습니다. 이전 기록은 유지됩니다.')),
      );
    }
  }

  Future<void> _requestHandoff() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          barrierColor: AppColors.scrim,
          builder: (_) => const _HandoffRequestDialog(),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final bool requested = await _viewModel.requestHandoff();
    if (!mounted) {
      return;
    }
    if (requested) {
      try {
        ref.invalidate(patientAssessmentViewModelProvider);
        await ref.read(clearPatientAssessmentDraftProvider).call();
      } finally {
        ref.invalidate(patientAssessmentViewModelProvider);
        if (mounted) {
          context.goNamed('home');
        }
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인계 요청을 보내지 못했습니다. 다시 시도해주세요.')),
    );
  }

  Future<void> _cancelTransport() async {
    final TransportCancellation? cancellation =
        await showTransportCancellationSheet(context);
    if (cancellation == null || !mounted) {
      return;
    }
    final bool cancelled = await _viewModel.cancel(cancellation);
    if (!mounted) {
      return;
    }
    if (cancelled) {
      ref.invalidate(patientAssessmentViewModelProvider);
      await ref.read(clearPatientAssessmentDraftProvider).call();
      ref.invalidate(patientAssessmentViewModelProvider);
      if (!mounted) {
        return;
      }
      context.goNamed('home');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('이송을 취소하지 못했습니다. 다시 시도해주세요.')));
  }
}

class _UrgentWithdrawalDialog extends StatefulWidget {
  const _UrgentWithdrawalDialog({required this.notice});

  final UrgentDestinationWithdrawal notice;

  @override
  State<_UrgentWithdrawalDialog> createState() =>
      _UrgentWithdrawalDialogState();
}

class _UrgentWithdrawalDialogState extends State<_UrgentWithdrawalDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _pulseController
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('urgentDestinationWithdrawalDialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (BuildContext context, Widget? child) {
          final Color background = Color.lerp(
            AppColors.negativeBackground,
            AppColors.negativeBorder,
            _pulseController.value * 0.55,
          )!;
          return Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: AppColors.statusNegative,
                width: 2 + _pulseController.value,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.statusNegative.withValues(
                    alpha: 0.18 + _pulseController.value * 0.18,
                  ),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.statusNegative,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.textOnDark,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '긴급 고지',
              style: TextStyle(
                color: AppColors.statusNegative,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.notice.hospitalName}에서\n수락을 철회했습니다',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              key: const Key('urgentWithdrawalReason'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '사유: ${widget.notice.reason}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '현재 목적지가 해제되었습니다. 확인 후 새로운 목적지를 직접 선택해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                key: const Key('confirmUrgentWithdrawalButton'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusNegative,
                  foregroundColor: AppColors.textOnDark,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoffBottomAction extends StatelessWidget {
  const _HandoffBottomAction({
    required this.isSubmitting,
    required this.isHandoffPending,
    required this.isCancelling,
    required this.isClinicalUpdateSaving,
    required this.onPressed,
    required this.onCancel,
  });

  final bool isSubmitting;
  final bool isHandoffPending;
  final bool isCancelling;
  final bool isClinicalUpdateSaving;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('inTransitBottomAction'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: isHandoffPending
          ? const SizedBox(
              height: 56,
              child: FilledButton(
                key: Key('handoffPendingButton'),
                onPressed: null,
                child: Text(
                  '병원 인계 확인 대기 중',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const Key('cancelInTransitButton'),
                      onPressed:
                          isSubmitting || isCancelling || isClinicalUpdateSaving
                          ? null
                          : onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusNegative,
                        side: const BorderSide(color: AppColors.negativeBorder),
                      ),
                      child: isCancelling
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : const Text(
                              '이송 취소',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      key: const Key('requestHandoffButton'),
                      onPressed:
                          isSubmitting || isCancelling || isClinicalUpdateSaving
                          ? null
                          : onPressed,
                      child: isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.textOnDark,
                              ),
                            )
                          : const Text(
                              '인계 요청',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HandoffRequestDialog extends StatelessWidget {
  const _HandoffRequestDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('confirmHandoffRequestDialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '환자 인계를\n요청할까요?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '요청 후 목적지 병원이 확인하기 전까지\n인계 대기 중으로 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('cancelHandoffRequestButton'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.disabled,
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: const Text('돌아가기'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('confirmHandoffRequestButton'),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('인계 요청'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationHospitalCard extends StatelessWidget {
  const _DestinationHospitalCard({
    required this.session,
    required this.locationSnapshot,
    required this.onCall,
    required this.onDirections,
  });

  final TransportSession session;
  final TransportLocationSnapshot? locationSnapshot;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final hospital = session.destination;
    final TransportLocationSnapshot? location = locationSnapshot;
    return Container(
      key: const Key('destinationHospitalCard'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.positiveBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '목적지 병원',
            style: TextStyle(
              color: AppColors.statusPositive,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hospital.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            hospital.fullAddress,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _CompactInfo(
                icon: Icons.near_me_outlined,
                text: location?.routeDistanceLabel ?? hospital.distanceLabel,
              ),
              if (location != null || hospital.etaLabel != null) ...<Widget>[
                const SizedBox(width: 14),
                _CompactInfo(
                  icon: Icons.schedule_outlined,
                  text: location?.etaLabel ?? hospital.etaLabel!,
                ),
              ],
            ],
          ),
          if (location != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              location.freshnessLabel,
              key: const Key('transportLocationFreshness'),
              style: TextStyle(
                color: location.isStale
                    ? AppColors.statusChecking
                    : AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (location.routeStatusLabel != null) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                location.routeStatusLabel!,
                key: const Key('transportRouteEstimateStatus'),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('callDestinationHospitalButton'),
              onPressed: onCall,
              icon: const Icon(Icons.phone_rounded),
              label: Text('응급실 전화 ${hospital.emergencyRoomPhone}'),
            ),
          ),
          if (hospital.latitude != null &&
              hospital.longitude != null) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('directionsDestinationHospitalButton'),
                onPressed: onDirections,
                icon: const Icon(Icons.directions_rounded),
                label: const Text('목적지 길찾기'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({required this.summary});

  final PatientTransportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('inTransitPatientSummary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '환자 최신 상태',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                (summary.lastClinicalUpdateAt ?? summary.vitalsMeasuredAt) ==
                        null
                    ? '측정 시각 확인 불가'
                    : '최신 갱신 ${formatClinicalTime(summary.lastClinicalUpdateAt ?? summary.vitalsMeasuredAt!)}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            rowKey: 'age',
            label: '나이',
            value: _withoutUnknownPrefix(summary.ageLabel, '나이'),
          ),
          _SummaryRow(
            rowKey: 'sex',
            label: '성별',
            value: _withoutUnknownPrefix(summary.sexLabel, '성별'),
          ),
          _SummaryRow(
            rowKey: 'symptom',
            label: '주증상',
            value: _withoutUnknownPrefix(summary.primarySymptomLabel, '주증상'),
          ),
          _SummaryRow(
            rowKey: 'preKtas',
            label: 'Pre-KTAS',
            value: _preKtasValue(summary.preKtasLabel),
            preKtasLevel: _preKtasLevel(summary.preKtasLabel),
          ),
          _SummaryRow(
            rowKey: 'avpu',
            label: '의식 (AVPU)',
            value: _avpuValue(summary.avpuLabel),
          ),
          if (summary.preKtasDetailLabel != null)
            _SummaryRow(
              rowKey: 'preKtasDetail',
              label: '분류 예외',
              value: summary.preKtasDetailLabel!,
            ),
          if (summary.consciousnessDetailLabel != null)
            _SummaryRow(
              rowKey: 'consciousnessDetail',
              label: '의식 평가',
              value: summary.consciousnessDetailLabel!,
            ),
          if (summary.hasIncidentDetails) ...<Widget>[
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 8),
            const Text('발생 정보', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (summary.occurrenceLabel != null)
              _SummaryRow(
                rowKey: 'occurrence',
                label: '발생 구분',
                value: summary.occurrenceLabel!,
              ),
            if (summary.occurrenceDetail != null)
              _SummaryRow(
                rowKey: 'occurrenceDetail',
                label: '발생 상세',
                value: summary.occurrenceDetail!,
              ),
            if (summary.injuryMechanismLabel != null)
              _SummaryRow(
                rowKey: 'injuryMechanism',
                label: '손상 기전',
                value: summary.injuryMechanismLabel!,
              ),
            if (summary.injurySitesLabel != null)
              _SummaryRow(
                rowKey: 'injurySites',
                label: '손상 부위',
                value: summary.injurySitesLabel!,
              ),
            if (summary.primarySymptomDetail != null)
              _SummaryRow(
                rowKey: 'primarySymptomDetail',
                label: '주증상 상세',
                value: summary.primarySymptomDetail!,
              ),
            if (summary.secondarySymptomsLabel != null)
              _SummaryRow(
                rowKey: 'secondarySymptoms',
                label: '부증상',
                value: summary.secondarySymptomsLabel!,
              ),
            if (summary.onsetLabel != null)
              _SummaryRow(
                rowKey: 'onset',
                label: '발생 시각',
                value: summary.onsetLabel!,
              ),
          ],
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          _SummaryRow(
            rowKey: 'bloodPressure',
            label: '혈압',
            value: summary.bloodPressureDisplay,
          ),
          _SummaryRow(
            rowKey: 'pulse',
            label: '맥박',
            value: summary.pulseDisplay,
          ),
          _SummaryRow(
            rowKey: 'respiratoryRate',
            label: '호흡수',
            value: summary.respiratoryRateDisplay,
          ),
          _SummaryRow(
            rowKey: 'temperature',
            label: '체온',
            value: summary.temperatureDisplay,
          ),
          _SummaryRow(
            rowKey: 'oxygenSaturation',
            label: '산소포화도',
            value: summary.oxygenSaturationDisplay,
          ),
          if (summary.hasSupplementalAssessment) ...<Widget>[
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '추가 평가',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (summary.supplementalAssessedAt != null)
                  Text(
                    formatClinicalTime(summary.supplementalAssessedAt!),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (summary.glucoseMgDl != null)
              _SummaryRow(
                rowKey: 'glucose',
                label: '혈당',
                value: '${summary.glucoseMgDl} mg/dL',
              ),
            if (summary.leftPupilLabel != null ||
                summary.rightPupilLabel != null)
              _SummaryRow(
                rowKey: 'pupils',
                label: '동공',
                value:
                    '좌 ${summary.leftPupilLabel ?? '-'} · 우 ${summary.rightPupilLabel ?? '-'}',
              ),
            if (summary.medicalHistory != null)
              _SummaryRow(
                rowKey: 'medicalHistory',
                label: '과거력',
                value: summary.medicalHistory!,
              ),
            if (summary.allergies != null)
              _SummaryRow(
                rowKey: 'allergies',
                label: '알레르기',
                value: summary.allergies!,
              ),
            if (summary.medications != null)
              _SummaryRow(
                rowKey: 'medications',
                label: '복용약',
                value: summary.medications!,
              ),
            if (summary.isolationConcern != null)
              _SummaryRow(
                rowKey: 'isolationConcern',
                label: '격리 우려',
                value: summary.isolationConcern! ? '있음' : '없음',
              ),
          ],
        ],
      ),
    );
  }

  String _withoutUnknownPrefix(String value, String label) {
    return value == '$label 확인 불가' ? '확인 불가' : value;
  }

  int? _preKtasLevel(String value) {
    return int.tryParse(RegExp(r'[1-5]').firstMatch(value)?.group(0) ?? '');
  }

  String _preKtasValue(String value) {
    final int? level = _preKtasLevel(value);
    return level == null ? value : '$level단계';
  }

  String _avpuValue(String value) {
    return switch (value) {
      'A' => 'A · 명료',
      'V' => 'V · 음성 반응',
      'P' => 'P · 통증 반응',
      'U' => 'U · 무반응',
      'UNASSESSABLE' => '평가 불가',
      _ => value,
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.rowKey,
    required this.label,
    required this.value,
    this.preKtasLevel,
  });

  final String rowKey;
  final String label;
  final String value;
  final int? preKtasLevel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: Key('patientSummaryRow_$rowKey'),
      constraints: const BoxConstraints(minHeight: 38),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _SummaryValue(
                  key: Key('patientSummaryValue_$rowKey'),
                  value: value,
                  preKtasLevel: preKtasLevel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({super.key, required this.value, this.preKtasLevel});

  final String value;
  final int? preKtasLevel;

  @override
  Widget build(BuildContext context) {
    final (Color?, Color, Color?) colors = _colors();
    final Text text = Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: colors.$2,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
    if (colors.$1 == null) {
      return text;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        border: colors.$3 == null ? null : Border.all(color: colors.$3!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: text,
    );
  }

  (Color?, Color, Color?) _colors() {
    if (preKtasLevel != null) {
      return (
        AppColors.preKtasButton(preKtasLevel!),
        AppColors.onPreKtasButton(preKtasLevel!),
        null,
      );
    }
    return (null, AppColors.textPrimary, null);
  }
}

class _ClinicalUpdateCard extends StatelessWidget {
  const _ClinicalUpdateCard({
    required this.isSavingVitals,
    required this.isSavingConsciousness,
    required this.isSavingPreKtas,
    required this.isSavingTreatment,
    required this.latestTreatmentLabel,
    required this.latestTreatmentAt,
    required this.onAddVitals,
    required this.onAddConsciousness,
    required this.onAddPreKtas,
    required this.onAddTreatment,
  });

  final bool isSavingVitals;
  final bool isSavingConsciousness;
  final bool isSavingPreKtas;
  final bool isSavingTreatment;
  final String? latestTreatmentLabel;
  final DateTime? latestTreatmentAt;
  final VoidCallback onAddVitals;
  final VoidCallback onAddConsciousness;
  final VoidCallback onAddPreKtas;
  final VoidCallback onAddTreatment;

  bool get _isSavingAny =>
      isSavingVitals ||
      isSavingConsciousness ||
      isSavingPreKtas ||
      isSavingTreatment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '이송 중 상태 업데이트',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            '새 상태를 기록하면 요약에는 최신 값이 표시되고, 이전 기록은 시간순으로 유지됩니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _ClinicalUpdateButton(
            buttonKey: const Key('addInTransitVitalsButton'),
            label: '활력징후 수정',
            icon: Icons.monitor_heart_outlined,
            primary: true,
            isSaving: isSavingVitals,
            isDisabled: _isSavingAny,
            onPressed: onAddVitals,
          ),
          const SizedBox(height: 9),
          _ClinicalUpdateButton(
            buttonKey: const Key('addInTransitConsciousnessButton'),
            label: '의식 상태 수정',
            icon: Icons.visibility_outlined,
            isSaving: isSavingConsciousness,
            isDisabled: _isSavingAny,
            onPressed: onAddConsciousness,
          ),
          const SizedBox(height: 9),
          _ClinicalUpdateButton(
            buttonKey: const Key('addInTransitPreKtasButton'),
            label: 'Pre-KTAS 수정',
            icon: Icons.assignment_outlined,
            isSaving: isSavingPreKtas,
            isDisabled: _isSavingAny,
            onPressed: onAddPreKtas,
          ),
          const SizedBox(height: 9),
          _ClinicalUpdateButton(
            buttonKey: const Key('addInTransitTreatmentButton'),
            label: '처치 기록 추가',
            icon: Icons.medical_services_outlined,
            isSaving: isSavingTreatment,
            isDisabled: _isSavingAny,
            onPressed: onAddTreatment,
          ),
          if (latestTreatmentLabel != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              key: const Key('latestInTransitTreatment'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '최근 처치  $latestTreatmentLabel',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (latestTreatmentAt != null)
                    Text(
                      formatClinicalTime(latestTreatmentAt!),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalUpdateButton extends StatelessWidget {
  const _ClinicalUpdateButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.isSaving,
    required this.isDisabled,
    required this.onPressed,
    this.primary = false,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final bool isSaving;
  final bool isDisabled;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = isSaving
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);
    final VoidCallback? callback = isDisabled ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: primary
          ? FilledButton.icon(
              key: buttonKey,
              onPressed: callback,
              icon: iconWidget,
              label: Text(isSaving ? '저장 중...' : label),
            )
          : OutlinedButton.icon(
              key: buttonKey,
              onPressed: callback,
              icon: iconWidget,
              label: Text(isSaving ? '저장 중...' : label),
            ),
    );
  }
}

class _VitalUpdateSheet extends StatefulWidget {
  const _VitalUpdateSheet({required this.summary});

  final PatientTransportSummary summary;

  @override
  State<_VitalUpdateSheet> createState() => _VitalUpdateSheetState();
}

class _VitalUpdateSheetState extends State<_VitalUpdateSheet> {
  late double _systolic;
  late double _diastolic;
  late double _pulse;
  late double _respiratoryRate;
  late double _temperature;
  late double _oxygenSaturation;

  @override
  void initState() {
    super.initState();
    _systolic = widget.summary.systolic ?? 105;
    _diastolic = widget.summary.diastolic ?? 70;
    _pulse = widget.summary.pulse ?? 80;
    _respiratoryRate = widget.summary.respiratoryRate ?? 15;
    _temperature = widget.summary.temperature ?? 37;
    _oxygenSaturation = widget.summary.oxygenSaturation ?? 98;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      key: const Key('inTransitVitalUpdateSheet'),
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '이송 중 활력징후 수정',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('inTransitVitalUpdateList'),
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  const Text(
                    '새로 측정한 값으로 수정한 뒤 측정 시간을 선택합니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  _InputLabel(
                    label: '혈압 · 수축기',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 수축기 혈압',
                      inputKey: const Key('inTransitSystolicInput'),
                      value: _systolic,
                      step: 1,
                      min: 0,
                      max: 300,
                      fallbackValue: 105,
                      unit: 'mmHg',
                      onChanged: (double? value) =>
                          setState(() => _systolic = value ?? _systolic),
                    ),
                  ),
                  _InputLabel(
                    label: '혈압 · 이완기',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 이완기 혈압',
                      inputKey: const Key('inTransitDiastolicInput'),
                      value: _diastolic,
                      step: 1,
                      min: 0,
                      max: 300,
                      fallbackValue: 70,
                      unit: 'mmHg',
                      onChanged: (double? value) =>
                          setState(() => _diastolic = value ?? _diastolic),
                    ),
                  ),
                  _InputLabel(
                    label: '맥박',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 맥박',
                      inputKey: const Key('inTransitPulseInput'),
                      value: _pulse,
                      step: 1,
                      min: 0,
                      max: 300,
                      fallbackValue: 80,
                      unit: 'bpm',
                      onChanged: (double? value) =>
                          setState(() => _pulse = value ?? _pulse),
                    ),
                  ),
                  _InputLabel(
                    label: '호흡수',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 호흡수',
                      inputKey: const Key('inTransitRespiratoryInput'),
                      value: _respiratoryRate,
                      step: 1,
                      min: 0,
                      max: 100,
                      fallbackValue: 15,
                      unit: '/min',
                      onChanged: (double? value) => setState(
                        () => _respiratoryRate = value ?? _respiratoryRate,
                      ),
                    ),
                  ),
                  _InputLabel(
                    label: '체온',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 체온',
                      inputKey: const Key('inTransitTemperatureInput'),
                      value: _temperature,
                      step: 0.1,
                      min: 0,
                      max: 50,
                      fallbackValue: 37,
                      decimalPlaces: 1,
                      unit: '°C',
                      onChanged: (double? value) =>
                          setState(() => _temperature = value ?? _temperature),
                    ),
                  ),
                  _InputLabel(
                    label: '산소포화도',
                    child: NumericStepperField(
                      semanticLabel: '이송 중 산소포화도',
                      inputKey: const Key('inTransitOxygenInput'),
                      value: _oxygenSaturation,
                      step: 1,
                      min: 0,
                      max: 100,
                      fallbackValue: 98,
                      unit: '%',
                      onChanged: (double? value) => setState(
                        () => _oxygenSaturation = value ?? _oxygenSaturation,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      key: const Key('continueInTransitVitalTimeButton'),
                      onPressed: () => Navigator.of(context).pop(
                        _VitalUpdateValues(
                          systolic: _systolic,
                          diastolic: _diastolic,
                          pulse: _pulse,
                          respiratoryRate: _respiratoryRate,
                          temperature: _temperature,
                          oxygenSaturation: _oxygenSaturation,
                        ),
                      ),
                      child: const Text('측정 시간 선택'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _VitalUpdateValues {
  const _VitalUpdateValues({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.respiratoryRate,
    required this.temperature,
    required this.oxygenSaturation,
  });

  final double systolic;
  final double diastolic;
  final double pulse;
  final double respiratoryRate;
  final double temperature;
  final double oxygenSaturation;
}
