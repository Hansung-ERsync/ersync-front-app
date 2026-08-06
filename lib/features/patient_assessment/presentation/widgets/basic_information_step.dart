import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../providers/patient_assessment_view_model.dart';
import 'assessment_choice.dart';
import 'assessment_section.dart';
import 'assessment_validation.dart';
import 'numeric_stepper_field.dart';

class BasicInformationStep extends StatelessWidget {
  const BasicInformationStep({
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
          target: AssessmentValidationTarget.age,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '나이 구분'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AgeStatus.values
                    .map(
                      (AgeStatus value) => AssessmentChoice(
                        key: Key('ageStatus_${value.apiValue}'),
                        label: value.label,
                        selected: draft.ageStatus == value,
                        selectedColor: value == AgeStatus.unknown
                            ? AppColors.statusUnavailable
                            : AppColors.primary,
                        onTap: () => viewModel.setAgeStatus(value),
                      ),
                    )
                    .toList(),
              ),
              if (draft.ageStatus != AgeStatus.unknown) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const Key('patientAgeStepper'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        draft.ageStatus == AgeStatus.estimated
                            ? '추정 나이'
                            : '만 나이',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      NumericStepperField(
                        semanticLabel: '환자 나이',
                        inputKey: const Key('patientAgeInput'),
                        value: draft.ageYears?.toDouble(),
                        step: 1,
                        min: 0,
                        max: 130,
                        fallbackValue: 40,
                        unit: '세',
                        onChanged: (double? value) =>
                            viewModel.setAgeYears(value?.round()),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        AssessmentValidationSection(
          target: AssessmentValidationTarget.sex,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '성별'),
              const SizedBox(height: 10),
              Row(
                children: PatientSex.values
                    .expand(
                      (PatientSex value) => <Widget>[
                        Expanded(
                          child: AssessmentChoice(
                            key: Key('patientSex_${value.apiValue}'),
                            label: value.label,
                            selected: draft.sex == value,
                            selectedColor: value == PatientSex.unknown
                                ? AppColors.statusUnavailable
                                : AppColors.primary,
                            onTap: () => viewModel.setSex(value),
                          ),
                        ),
                        if (value != PatientSex.values.last)
                          const SizedBox(width: 8),
                      ],
                    )
                    .toList(),
              ),
              if (draft.occurrenceType == OccurrenceType.other) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('occurrenceDetailInput'),
                  initialValue: draft.occurrenceDetail,
                  maxLength: 200,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '기타 발생 유형 상세',
                    hintText: '발생 상황을 입력해주세요',
                  ),
                  onChanged: viewModel.setOccurrenceDetail,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        AssessmentValidationSection(
          target: AssessmentValidationTarget.occurrenceType,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(title: '발생 유형'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OccurrenceType.values
                    .map(
                      (OccurrenceType value) => AssessmentChoice(
                        key: Key('occurrenceType_${value.apiValue}'),
                        label: value.label,
                        selected: draft.occurrenceType == value,
                        selectedColor: value == OccurrenceType.unknown
                            ? AppColors.statusUnavailable
                            : AppColors.primary,
                        onTap: () => viewModel.setOccurrenceType(value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        if (draft.occurrenceType == OccurrenceType.nonDisease) ...<Widget>[
          const SizedBox(height: 28),
          AssessmentValidationSection(
            target: AssessmentValidationTarget.mechanism,
            activeTarget: validationTarget,
            message: validationMessage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AssessmentSectionTitle(title: '손상 기전'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: InjuryMechanism.values
                      .map(
                        (InjuryMechanism value) => AssessmentChoice(
                          key: Key('injuryMechanism_${value.apiValue}'),
                          label: value.label,
                          selected: draft.mechanism == value,
                          selectedColor: value == InjuryMechanism.unknown
                              ? AppColors.statusUnavailable
                              : AppColors.primary,
                          onTap: () => viewModel.setMechanism(value),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AssessmentValidationSection(
            target: AssessmentValidationTarget.injurySites,
            activeTarget: validationTarget,
            message: validationMessage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AssessmentSectionTitle(
                  title: '손상 부위',
                  description: '여러 부위를 선택할 수 있습니다.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: InjurySite.values
                      .map(
                        (InjurySite value) => AssessmentChoice(
                          key: Key('injurySite_${value.apiValue}'),
                          label: value.label,
                          selected: draft.injurySites.contains(value),
                          selectedColor: value == InjurySite.unknown
                              ? AppColors.statusUnavailable
                              : AppColors.primary,
                          onTap: () => viewModel.toggleInjurySite(value),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
