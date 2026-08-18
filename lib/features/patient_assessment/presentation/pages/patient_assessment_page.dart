import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../hospital_search/domain/entities/hospital_search_session.dart';
import '../../../transport/domain/entities/patient_transport_summary.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';
import '../providers/patient_assessment_view_model.dart';
import '../widgets/assessment_validation.dart';
import '../widgets/basic_information_step.dart';
import '../widgets/clinical_classification_step.dart';
import '../widgets/clinical_time_editor.dart';
import '../widgets/treatment_review_step.dart';
import '../widgets/vital_signs_step.dart';

class PatientAssessmentPage extends ConsumerWidget {
  const PatientAssessmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PatientAssessmentViewState> asyncState = ref.watch(
      patientAssessmentViewModelProvider,
    );
    Future<void> discardDraft() =>
        ref.read(patientAssessmentViewModelProvider.notifier).discardDraft();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: asyncState.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _LoadError(
            onRetry: () => ref.invalidate(patientAssessmentViewModelProvider),
            onBack: context.pop,
          ),
          data: (PatientAssessmentViewState state) => _AssessmentBody(
            state: state,
            viewModel: ref.read(patientAssessmentViewModelProvider.notifier),
            onExit: discardDraft,
          ),
        ),
      ),
    );
  }
}

class _AssessmentBody extends StatefulWidget {
  const _AssessmentBody({
    required this.state,
    required this.viewModel,
    required this.onExit,
  });

  final PatientAssessmentViewState state;
  final PatientAssessmentViewModel viewModel;
  final Future<void> Function() onExit;

  @override
  State<_AssessmentBody> createState() => _AssessmentBodyState();
}

class _AssessmentBodyState extends State<_AssessmentBody> {
  late final ScrollController _scrollController;
  Timer? _validationTimer;
  bool _isExiting = false;

  PatientAssessmentViewState get state => widget.state;
  PatientAssessmentViewModel get viewModel => widget.viewModel;

  static const List<String> _stepTitles = <String>[
    '환자 기본 정보',
    '증상 및 중증도',
    '활력징후 입력',
    '처치 및 전송 확인',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _AssessmentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.step != widget.state.step) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    final bool validationChanged =
        oldWidget.state.validationTarget != widget.state.validationTarget ||
        oldWidget.state.errorMessage != widget.state.errorMessage;
    if (widget.state.validationTarget == null) {
      _validationTimer?.cancel();
    } else if (validationChanged) {
      _showValidationAtTarget(widget.state.validationTarget!);
    }
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isStepValid = viewModel.isStepValid(state.step, state.draft);
    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (state.step == 0) {
          unawaited(_discardDraftAndExit());
        } else {
          viewModel.previousStep();
        }
      },
      child: Column(
        children: <Widget>[
          _AssessmentHeader(
            title: _stepTitles[state.step],
            step: state.step,
            totalSteps: state.totalSteps,
            onBack: () {
              if (state.step == 0) {
                unawaited(_discardDraftAndExit());
              } else {
                viewModel.previousStep();
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _LocationBanner(
                    address: state.draft.sceneAddress,
                    isPreparing: state.isPreparingRequest,
                    errorMessage: state.preparationErrorMessage,
                    onRetry: viewModel.retryPreparation,
                  ),
                  if (state.errorMessage != null &&
                      state.validationTarget == null) ...<Widget>[
                    const SizedBox(height: 12),
                    _ValidationBanner(message: state.errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey<int>(state.step),
                      child: _buildStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomAction(
            isLastStep: state.step == state.totalSteps - 1,
            isBusy: state.isBusy,
            isEnabled:
                isStepValid &&
                (state.step < state.totalSteps - 1 || state.isDraftReady),
            disabledMessage:
                isStepValid &&
                    state.step == state.totalSteps - 1 &&
                    !state.isDraftReady
                ? state.isPreparingRequest
                      ? '최신 GPS 위치를 확인하면 이송 요청을 보낼 수 있습니다.'
                      : '위치 확인을 다시 시도한 뒤 이송 요청을 보내주세요.'
                : null,
            onPressed: () => _handlePrimaryAction(context),
          ),
        ],
      ),
    );
  }

  Future<void> _discardDraftAndExit() async {
    if (_isExiting) {
      return;
    }
    setState(() => _isExiting = true);
    await widget.onExit();
    if (mounted) {
      context.pop();
    }
  }

  Widget _buildStep() {
    return switch (state.step) {
      0 => BasicInformationStep(
        draft: state.draft,
        viewModel: viewModel,
        validationTarget: state.validationTarget,
        validationMessage: state.errorMessage,
      ),
      1 => ClinicalClassificationStep(
        draft: state.draft,
        viewModel: viewModel,
        validationTarget: state.validationTarget,
        validationMessage: state.errorMessage,
      ),
      2 => VitalSignsStep(
        draft: state.draft,
        viewModel: viewModel,
        validationTarget: state.validationTarget,
        validationMessage: state.errorMessage,
      ),
      _ => TreatmentReviewStep(
        draft: state.draft,
        viewModel: viewModel,
        validationTarget: state.validationTarget,
        validationMessage: state.errorMessage,
      ),
    };
  }

  void _showValidationAtTarget(AssessmentValidationTarget target) {
    _validationTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final BuildContext? targetContext = assessmentValidationKey(
        target,
      ).currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
    });
    _validationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        viewModel.clearValidationMessage();
      }
    });
  }

  Future<void> _handlePrimaryAction(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (state.step < state.totalSteps - 1) {
      if (!await _confirmStepTime(context) || !context.mounted) {
        return;
      }
      await viewModel.nextStep();
      return;
    }

    if (!await _confirmStepTime(context) || !context.mounted) {
      return;
    }
    final TransferRequestReceipt? receipt = await viewModel.submit();
    if (receipt == null || !context.mounted) {
      return;
    }

    context.goNamed(
      'hospitalSearch',
      pathParameters: <String, String>{'requestId': receipt.requestId},
      extra: HospitalSearchSession(
        requestId: receipt.requestId,
        startedAt: receipt.createdAt,
        initialRadiusKm: receipt.currentSearchRadiusKm,
        radiusStepKm: receipt.radiusStepKm,
        expansionIntervalSeconds: receipt.expansionIntervalSeconds,
        maximumRadiusKm: receipt.maximumSearchRadiusKm,
        patientSummary: _buildTransportPatientSummary(),
      ),
    );
  }

  PatientTransportSummary _buildTransportPatientSummary() {
    final draft = state.draft;
    final bloodPressure = draft.vitals[VitalType.bloodPressure];
    return PatientTransportSummary(
      ageLabel: draft.ageStatus == AgeStatus.unknown
          ? '나이 확인 불가'
          : '${draft.ageYears ?? '-'}세${draft.ageStatus == AgeStatus.estimated ? ' 추정' : ''}',
      sexLabel: draft.sex?.label ?? '성별 확인 불가',
      primarySymptomLabel: draft.primarySymptom?.label ?? '주증상 확인 불가',
      preKtasLabel: draft.classificationStatus == ClassificationStatus.completed
          ? 'Pre-KTAS ${draft.preKtasLevel ?? '-'}'
          : '긴급 전송',
      avpuLabel: draft.avpu?.apiValue ?? '확인 불가',
      preKtasStandardVersion: draft.preKtasStandardVersion,
      systolic: bloodPressure?.value,
      diastolic: bloodPressure?.secondaryValue,
      pulse: draft.vitals[VitalType.pulse]?.value,
      respiratoryRate: draft.vitals[VitalType.respiratoryRate]?.value,
      temperature: draft.vitals[VitalType.temperature]?.value,
      oxygenSaturation: draft.vitals[VitalType.oxygenSaturation]?.value,
      vitalsMeasuredAt: draft.measuredAt,
      bloodPressureStateLabel: _vitalStateLabel(bloodPressure),
      pulseStateLabel: _vitalStateLabel(draft.vitals[VitalType.pulse]),
      respiratoryRateStateLabel: _vitalStateLabel(
        draft.vitals[VitalType.respiratoryRate],
      ),
      temperatureStateLabel: _vitalStateLabel(
        draft.vitals[VitalType.temperature],
      ),
      oxygenSaturationStateLabel: _vitalStateLabel(
        draft.vitals[VitalType.oxygenSaturation],
      ),
    );
  }

  String _vitalStateLabel(VitalReadingDraft? reading) {
    return switch (reading?.state) {
      MeasurementState.value => '측정값 확인 필요',
      MeasurementState.refused => MeasurementState.refused.label,
      MeasurementState.unavailable => _unavailableVitalLabel(reading!),
      null => '확인 불가',
    };
  }

  String _unavailableVitalLabel(VitalReadingDraft reading) {
    final MeasurementUnavailableReason? reason = reading.unavailableReason;
    if (reason == null) {
      return MeasurementState.unavailable.label;
    }
    if (reason == MeasurementUnavailableReason.other &&
        reading.unavailableReasonDetail.trim().isNotEmpty) {
      return '측정 불가 (사유: ${reading.unavailableReasonDetail.trim()})';
    }
    return '측정 불가 (사유: ${reason.label})';
  }

  Future<bool> _confirmStepTime(BuildContext context) async {
    if (state.step == 0) {
      final OnsetTimeSelection? selection = await showOnsetTimePickerSheet(
        context: context,
        initialTime: state.draft.onsetAt ?? DateTime.now(),
        initialStatus: state.draft.onsetTimeStatus,
        sheetKey: const Key('onsetTimeSheet'),
        confirmButtonKey: const Key('confirmOnsetAtButton'),
      );
      if (selection == null) {
        return false;
      }
      viewModel.setOnsetTimeSelection(selection.status, selection.occurredAt);
      return true;
    }

    final (
      String title,
      String description,
      DateTime initialTime,
      Key sheetKey,
      Key confirmButtonKey,
    )
    config = switch (state.step) {
      1 => (
        '분류·관찰 시각을 선택해주세요',
        'Pre-KTAS 분류와 AVPU를 관찰한 시각을 입력합니다.',
        state.draft.assessedAt,
        const Key('assessmentTimeSheet'),
        const Key('confirmAssessedAtButton'),
      ),
      2 => (
        '측정 시간을 확인해주세요',
        '활력징후를 실제로 측정한 시각을 선택한 뒤 다음 단계로 이동합니다.',
        state.draft.measuredAt,
        const Key('measurementTimeSheet'),
        const Key('confirmMeasuredAtButton'),
      ),
      _ => (
        '처치·확인 시각을 선택해주세요',
        '처치를 시행했거나 처치 없음으로 확인한 시각을 입력합니다.',
        state.draft.performedAt,
        const Key('treatmentTimeSheet'),
        const Key('confirmPerformedAtButton'),
      ),
    };

    final DateTime? selected = await showClinicalTimePickerSheet(
      context: context,
      title: config.$1,
      description: config.$2,
      initialTime: config.$3,
      sheetKey: config.$4,
      confirmButtonKey: config.$5,
    );
    if (selected == null) {
      return false;
    }
    switch (state.step) {
      case 1:
        viewModel.setAssessmentTime(selected);
        break;
      case 2:
        viewModel.setMeasuredAt(selected);
        break;
      default:
        viewModel.setPerformedAt(selected);
    }
    return true;
  }
}

class _AssessmentHeader extends StatelessWidget {
  const _AssessmentHeader({
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  final String title;
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const Key('assessmentBackButton'),
                  onPressed: onBack,
                  tooltip: step == 0 ? '홈으로 돌아가기' : '이전 단계',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${step + 1} / $totalSteps',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(totalSteps, (int index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index == totalSteps - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? AppColors.primary
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.address,
    required this.isPreparing,
    required this.errorMessage,
    required this.onRetry,
  });

  final String address;
  final bool isPreparing;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorMessage != null;
    final Color foreground = hasError
        ? AppColors.statusNegative
        : isPreparing
        ? AppColors.statusChecking
        : AppColors.statusPositive;
    final Color background = hasError
        ? AppColors.negativeBackground
        : isPreparing
        ? AppColors.checkingBackground
        : AppColors.positiveBackground;
    final Color border = hasError
        ? AppColors.negativeBorder
        : isPreparing
        ? AppColors.checkingBorder
        : AppColors.positiveBorder;
    final String label = hasError
        ? '전송 준비 필요'
        : isPreparing
        ? 'GPS 확인 중'
        : 'GPS 연결됨';
    final String detail = hasError
        ? errorMessage!
        : isPreparing
        ? '입력은 바로 시작할 수 있습니다.'
        : address;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          if (isPreparing && !hasError)
            SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else
            Icon(
              hasError
                  ? Icons.location_off_outlined
                  : Icons.location_on_outlined,
              color: foreground,
              size: 18,
            ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: hasError ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          if (hasError) ...<Widget>[
            const SizedBox(width: 4),
            IconButton(
              key: const Key('retryAssessmentPreparationButton'),
              tooltip: '다시 시도',
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              color: foreground,
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negativeBackground,
        border: Border.all(color: AppColors.negativeBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.statusNegative,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.statusNegative),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.isLastStep,
    required this.isBusy,
    required this.isEnabled,
    this.disabledMessage,
    required this.onPressed,
  });

  final bool isLastStep;
  final bool isBusy;
  final bool isEnabled;
  final String? disabledMessage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isEnabled && !isBusy) ...<Widget>[
            Text(
              disabledMessage ?? '필수 항목을 모두 입력하면 다음으로 이동할 수 있습니다.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: Key(
                isLastStep
                    ? 'submitTransferRequestButton'
                    : 'assessmentNextButton',
              ),
              onPressed: isBusy || !isEnabled ? null : onPressed,
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnDark,
                      ),
                    )
                  : Text(isLastStep ? '주변 병원에 이송 요청 보내기' : '다음'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            const Text('환자 평가 초안을 불러오지 못했습니다.'),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            TextButton(onPressed: onBack, child: const Text('홈으로 돌아가기')),
          ],
        ),
      ),
    );
  }
}
