import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../providers/patient_assessment_view_model.dart';
import 'assessment_choice.dart';
import 'assessment_section.dart';
import 'assessment_validation.dart';
import 'numeric_stepper_field.dart';

class VitalSignsStep extends StatelessWidget {
  const VitalSignsStep({
    super.key,
    required this.draft,
    required this.viewModel,
    required this.validationTarget,
    required this.validationMessage,
  });

  final PatientAssessmentDraft draft;
  final PatientAssessmentViewModel viewModel;
  final AssessmentValidationTarget? validationTarget;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AssessmentSectionTitle(
          title: '활력징후',
          description: '숫자를 직접 입력하거나 −/＋ 버튼으로 조절할 수 있습니다.',
        ),
        const SizedBox(height: 6),
        const Text(
          '측정하지 못한 항목은 빈칸 대신 상태와 사유를 기록합니다.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...VitalType.values.map((VitalType type) {
          final VitalReadingDraft reading =
              draft.vitals[type] ?? const VitalReadingDraft();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AssessmentValidationSection(
              target: validationTargetForVital(type),
              activeTarget: validationTarget,
              message: validationMessage,
              child: _VitalCard(
                type: type,
                reading: reading,
                onStateChanged: (MeasurementState value) =>
                    viewModel.setVitalState(type, value),
                onReasonChanged: (MeasurementUnavailableReason value) =>
                    viewModel.setVitalUnavailableReason(type, value),
                onReasonDetailChanged: (String value) =>
                    viewModel.setVitalUnavailableReasonDetail(type, value),
                onValueChanged: (double? value) =>
                    viewModel.setVitalValue(type, value),
                onSecondaryValueChanged: (double? value) =>
                    viewModel.setVitalValue(type, value, secondary: true),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.type,
    required this.reading,
    required this.onStateChanged,
    required this.onReasonChanged,
    required this.onReasonDetailChanged,
    required this.onValueChanged,
    required this.onSecondaryValueChanged,
  });

  final VitalType type;
  final VitalReadingDraft reading;
  final ValueChanged<MeasurementState> onStateChanged;
  final ValueChanged<MeasurementUnavailableReason> onReasonChanged;
  final ValueChanged<String> onReasonDetailChanged;
  final ValueChanged<double?> onValueChanged;
  final ValueChanged<double?> onSecondaryValueChanged;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = switch (reading.state) {
      MeasurementState.value => AppColors.surface,
      MeasurementState.unavailable => AppColors.checkingBackground,
      MeasurementState.refused => AppColors.negativeBackground,
      null => AppColors.surface,
    };
    final Color borderColor = switch (reading.state) {
      MeasurementState.value => AppColors.border,
      MeasurementState.unavailable => AppColors.checkingBorder,
      MeasurementState.refused => AppColors.negativeBorder,
      null => AppColors.border,
    };
    return AnimatedContainer(
      key: Key('vitalCard_${type.name}'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width:
              reading.state == null || reading.state == MeasurementState.value
              ? 1
              : 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  type.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                type.unit,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MeasurementState.values
                .map(
                  (MeasurementState value) => AssessmentChoice(
                    key: Key('vitalState_${type.name}_${value.apiValue}'),
                    label: value.label,
                    selected: reading.state == value,
                    selectedColor: switch (value) {
                      MeasurementState.value => AppColors.primary,
                      MeasurementState.unavailable => AppColors.statusChecking,
                      MeasurementState.refused => AppColors.statusNegative,
                    },
                    onTap: () => onStateChanged(value),
                  ),
                )
                .toList(),
          ),
          if (reading.state == MeasurementState.value) ...<Widget>[
            const SizedBox(height: 12),
            if (type == VitalType.bloodPressure)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LabeledVitalInput(
                    label: '수축기',
                    child: NumericStepperField(
                      semanticLabel: '수축기 혈압',
                      inputKey: const Key('systolicBloodPressureInput'),
                      value: reading.value,
                      step: type.step,
                      min: 0,
                      max: 300,
                      fallbackValue: 105,
                      unit: 'mmHg',
                      onChanged: onValueChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _LabeledVitalInput(
                    label: '이완기',
                    child: NumericStepperField(
                      semanticLabel: '이완기 혈압',
                      inputKey: const Key('diastolicBloodPressureInput'),
                      value: reading.secondaryValue,
                      step: type.step,
                      min: 0,
                      max: 300,
                      fallbackValue: 70,
                      unit: 'mmHg',
                      onChanged: onSecondaryValueChanged,
                    ),
                  ),
                ],
              )
            else
              NumericStepperField(
                semanticLabel: type.label,
                inputKey: Key('vitalInput_${type.name}'),
                value: reading.value,
                step: type.step,
                min: 0,
                max: _maxValue(type),
                fallbackValue: _fallbackValue(type),
                decimalPlaces: type == VitalType.temperature ? 1 : 0,
                unit: type.unit,
                onChanged: onValueChanged,
              ),
          ],
          if (reading.state == MeasurementState.unavailable) ...<Widget>[
            const SizedBox(height: 10),
            _UnavailableReasonField(
              key: Key('vitalUnavailableReason_${type.name}'),
              vitalType: type,
              selectedReason: reading.unavailableReason,
              onChanged: onReasonChanged,
            ),
            if (reading.unavailableReason ==
                MeasurementUnavailableReason.other) ...<Widget>[
              const SizedBox(height: 10),
              TextFormField(
                key: Key('vitalUnavailableDetail_${type.name}'),
                initialValue: reading.unavailableReasonDetail,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '기타 사유 직접 입력',
                  hintText: '측정하지 못한 이유를 입력해주세요',
                  fillColor: AppColors.surface,
                ),
                onChanged: onReasonDetailChanged,
              ),
            ],
          ],
        ],
      ),
    );
  }

  double _maxValue(VitalType type) {
    return switch (type) {
      VitalType.bloodPressure => 300,
      VitalType.pulse => 300,
      VitalType.respiratoryRate => 100,
      VitalType.temperature => 50,
      VitalType.oxygenSaturation => 100,
    };
  }

  double _fallbackValue(VitalType type) {
    return switch (type) {
      VitalType.bloodPressure => 105,
      VitalType.pulse => 80,
      VitalType.respiratoryRate => 15,
      VitalType.temperature => 37,
      VitalType.oxygenSaturation => 98,
    };
  }
}

class _UnavailableReasonField extends StatelessWidget {
  const _UnavailableReasonField({
    super.key,
    required this.vitalType,
    required this.selectedReason,
    required this.onChanged,
  });

  final VitalType vitalType;
  final MeasurementUnavailableReason? selectedReason;
  final ValueChanged<MeasurementUnavailableReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.checkingBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.statusChecking,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '측정 불가 사유',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedReason?.label ?? '사유를 선택해주세요',
                      style: TextStyle(
                        color: selectedReason == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final MeasurementUnavailableReason? reason =
        await showModalBottomSheet<MeasurementUnavailableReason>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (BuildContext context) => _UnavailableReasonSheet(
            vitalType: vitalType,
            selectedReason: selectedReason,
          ),
        );
    if (reason != null) {
      onChanged(reason);
    }
  }
}

class _UnavailableReasonSheet extends StatelessWidget {
  const _UnavailableReasonSheet({
    required this.vitalType,
    required this.selectedReason,
  });

  final VitalType vitalType;
  final MeasurementUnavailableReason? selectedReason;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('vitalUnavailableReasonSheet'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${vitalType.label} 측정 불가 사유',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '닫기',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '현장에서 측정하지 못한 가장 가까운 사유를 선택해주세요.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...MeasurementUnavailableReason.values.map(
            (MeasurementUnavailableReason reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UnavailableReasonOption(
                reason: reason,
                selected: selectedReason == reason,
                onTap: () => Navigator.of(context).pop(reason),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableReasonOption extends StatelessWidget {
  const _UnavailableReasonOption({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final MeasurementUnavailableReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.checkingBackground : AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? AppColors.checkingBorder : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        key: Key('unavailableReasonOption_${reason.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.checkingBorder
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _reasonIcon(reason),
                  color: AppColors.statusChecking,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reason.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _reasonDescription(reason),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.statusChecking,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _reasonIcon(MeasurementUnavailableReason reason) {
    return switch (reason) {
      MeasurementUnavailableReason.patientCondition =>
        Icons.personal_injury_outlined,
      MeasurementUnavailableReason.sceneDanger => Icons.warning_amber_rounded,
      MeasurementUnavailableReason.injurySite => Icons.healing_outlined,
      MeasurementUnavailableReason.deviceError => Icons.build_circle_outlined,
      MeasurementUnavailableReason.other => Icons.more_horiz_rounded,
    };
  }

  String _reasonDescription(MeasurementUnavailableReason reason) {
    return switch (reason) {
      MeasurementUnavailableReason.patientCondition =>
        '환자 상태로 측정 자세나 접촉을 유지하기 어려운 경우',
      MeasurementUnavailableReason.sceneDanger =>
        '구급대원 또는 환자의 안전을 우선해야 하는 현장인 경우',
      MeasurementUnavailableReason.injurySite => '손상 부위 때문에 장비 적용이나 측정이 어려운 경우',
      MeasurementUnavailableReason.deviceError =>
        '장비 고장, 배터리 또는 센서 문제로 값을 얻지 못한 경우',
      MeasurementUnavailableReason.other =>
        '위 항목에 해당하지 않아 구체적인 사유를 직접 입력해야 하는 경우',
    };
  }
}

class _LabeledVitalInput extends StatelessWidget {
  const _LabeledVitalInput({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
