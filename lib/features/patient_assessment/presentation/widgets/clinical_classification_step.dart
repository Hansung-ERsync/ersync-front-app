import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../providers/patient_assessment_view_model.dart';
import 'assessment_choice.dart';
import 'assessment_section.dart';
import 'assessment_validation.dart';

class ClinicalClassificationStep extends StatelessWidget {
  const ClinicalClassificationStep({
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
        AssessmentValidationSection(
          target: AssessmentValidationTarget.primarySymptom,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '주증상'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PatientSymptom.values
                    .map(
                      (PatientSymptom value) => AssessmentChoice(
                        key: Key('primarySymptom_${value.apiValue}'),
                        label: value.label,
                        selected: draft.primarySymptom == value,
                        onTap: () => viewModel.setPrimarySymptom(value),
                        selectedColor: value == PatientSymptom.unknown
                            ? AppColors.statusUnavailable
                            : AppColors.statusInfo,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const AssessmentSectionTitle(
          title: '부증상',
          description: '해당하는 증상을 모두 선택하세요.',
          required: false,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PatientSymptom.values
              .where((PatientSymptom value) => value != draft.primarySymptom)
              .map(
                (PatientSymptom value) => AssessmentChoice(
                  key: Key('secondarySymptom_${value.apiValue}'),
                  label: value.label,
                  selected: draft.secondarySymptoms.contains(value),
                  selectedColor: value == PatientSymptom.unknown
                      ? AppColors.statusUnavailable
                      : AppColors.primary,
                  onTap: () => viewModel.toggleSecondarySymptom(value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        AssessmentValidationSection(
          target: AssessmentValidationTarget.classification,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '중증도 분류'),
              const SizedBox(height: 10),
              Row(
                children: ClassificationStatus.values
                    .expand(
                      (ClassificationStatus value) => <Widget>[
                        Expanded(
                          child: AssessmentChoice(
                            key: Key('classificationStatus_${value.apiValue}'),
                            label: value == ClassificationStatus.completed
                                ? '분류 완료'
                                : '긴급 전송',
                            selected: draft.classificationStatus == value,
                            selectedColor:
                                value ==
                                    ClassificationStatus.emergencyUnfinished
                                ? AppColors.statusRefused
                                : AppColors.primary,
                            onTap: () =>
                                viewModel.setClassificationStatus(value),
                          ),
                        ),
                        if (value != ClassificationStatus.values.last)
                          const SizedBox(width: 8),
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (draft.classificationStatus == ClassificationStatus.completed)
          AssessmentValidationSection(
            target: AssessmentValidationTarget.preKtas,
            activeTarget: validationTarget,
            message: validationMessage,
            child: _PreKtasSelector(
              selectedLevel: draft.preKtasLevel,
              onSelected: viewModel.setPreKtasLevel,
            ),
          )
        else if (draft.classificationStatus ==
            ClassificationStatus.emergencyUnfinished)
          _EmergencyExceptionFields(
            draft: draft,
            viewModel: viewModel,
            validationTarget: validationTarget,
            validationMessage: validationMessage,
          ),
        const SizedBox(height: 28),
        AssessmentValidationSection(
          target: AssessmentValidationTarget.avpu,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '의식 상태 (AVPU)'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AvpuLevel.values
                    .map(
                      (AvpuLevel value) => AssessmentChoice(
                        key: Key('avpu_${value.apiValue}'),
                        label: '${value.label} (${value.apiValue})',
                        selected: draft.avpu == value,
                        selectedColor: value == AvpuLevel.unassessable
                            ? AppColors.statusUnavailable
                            : AppColors.primary,
                        onTap: () => viewModel.setAvpu(value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        if (draft.avpu == AvpuLevel.unassessable) ...<Widget>[
          const SizedBox(height: 12),
          AssessmentValidationSection(
            target: AssessmentValidationTarget.unassessableReason,
            activeTarget: validationTarget,
            message: validationMessage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.unavailableBackground,
                border: Border.all(color: AppColors.unavailableBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UnassessableReason.values
                    .map(
                      (UnassessableReason value) => AssessmentChoice(
                        key: Key('unassessableReason_${value.apiValue}'),
                        label: value.label,
                        selected: draft.unassessableReason == value,
                        selectedColor: AppColors.statusUnavailable,
                        onTap: () => viewModel.setUnassessableReason(value),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Row(
          children: <Widget>[
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.statusInfo,
              size: 20,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '다음을 누르면 분류·관찰 시각을 선택합니다.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreKtasSelector extends StatelessWidget {
  const _PreKtasSelector({
    required this.selectedLevel,
    required this.onSelected,
  });

  final int? selectedLevel;
  final ValueChanged<int> onSelected;

  static const Map<int, String> _labels = <int, String>{
    1: '소생',
    2: '긴급',
    3: '응급',
    4: '준응급',
    5: '비응급',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(5, (int index) {
            final int level = index + 1;
            final bool selected = selectedLevel == level;
            final Color color = AppColors.preKtasButton(level);
            final Color foreground = AppColors.onPreKtasButton(level);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: level == 5 ? 0 : 6),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: 'Pre-KTAS $level단계 ${_labels[level]}',
                  child: Material(
                    color: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected ? AppColors.primary : color,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: InkWell(
                      key: Key('preKtasLevel$level'),
                      onTap: () => onSelected(level),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 76,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              '$level',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _labels[level]!,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pre-KTAS 기준 버전은 개발 환경 미확정 값으로 저장됩니다.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmergencyExceptionFields extends StatelessWidget {
  const _EmergencyExceptionFields({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.checkingBackground,
        border: Border.all(color: AppColors.checkingBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pre-KTAS를 완료하지 못한 사유',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          AssessmentValidationSection(
            target: AssessmentValidationTarget.exceptionReason,
            activeTarget: validationTarget,
            message: validationMessage,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmergencyExceptionReason.values
                  .map(
                    (EmergencyExceptionReason value) => AssessmentChoice(
                      key: Key('emergencyReason_${value.apiValue}'),
                      label: value.label,
                      selected: draft.exceptionReason == value,
                      selectedColor: AppColors.statusRefused,
                      onTap: () => viewModel.setEmergencyReason(value),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (draft.exceptionReason ==
              EmergencyExceptionReason.other) ...<Widget>[
            const SizedBox(height: 12),
            AssessmentValidationSection(
              target: AssessmentValidationTarget.exceptionDetail,
              activeTarget: validationTarget,
              message: validationMessage,
              child: TextFormField(
                key: const Key('emergencyExceptionDetailInput'),
                initialValue: draft.exceptionDetail,
                minLines: 2,
                maxLines: 3,
                maxLength: 120,
                decoration: const InputDecoration(
                  hintText: '기타 사유를 입력해주세요',
                  fillColor: AppColors.surface,
                ),
                onChanged: viewModel.setExceptionDetail,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
