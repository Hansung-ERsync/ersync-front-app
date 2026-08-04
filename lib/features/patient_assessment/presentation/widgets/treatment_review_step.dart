import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../providers/patient_assessment_view_model.dart';
import 'assessment_choice.dart';
import 'assessment_section.dart';
import 'assessment_validation.dart';
import 'numeric_stepper_field.dart';

class TreatmentReviewStep extends StatelessWidget {
  const TreatmentReviewStep({
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
          target: AssessmentValidationTarget.treatments,
          activeTarget: validationTarget,
          message: validationMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AssessmentSectionTitle(
                title: '시행한 처치',
                description: '처치가 없으면 “처치 없음”을 선택하세요.',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TreatmentType.values
                    .map(
                      (TreatmentType value) => AssessmentChoice(
                        key: Key('treatment_${value.apiValue}'),
                        label: value.label,
                        selected: draft.treatments.contains(value),
                        onTap: () => viewModel.toggleTreatment(value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                '이송 요청 버튼을 누르면 처치·확인 시각을 선택합니다.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const AssessmentSectionTitle(
          title: '상황별 추가 평가',
          description: '발동 규칙 확정 전 개발용 선택 입력입니다.',
          required: false,
        ),
        const SizedBox(height: 10),
        _SupplementalAssessmentCard(
          draft: draft,
          viewModel: viewModel,
          validationTarget: validationTarget,
          validationMessage: validationMessage,
        ),
      ],
    );
  }
}

class _SupplementalAssessmentCard extends StatelessWidget {
  const _SupplementalAssessmentCard({
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          SwitchListTile.adaptive(
            key: const Key('glucoseToggle'),
            value: draft.glucoseMgDl != null,
            onChanged: (_) => viewModel.toggleGlucose(),
            title: const Text(
              '혈당 측정',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('필요한 상황에서 선택 입력'),
          ),
          if (draft.glucoseMgDl != null) ...<Widget>[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '혈당',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  NumericStepperField(
                    semanticLabel: '혈당',
                    inputKey: const Key('glucoseInput'),
                    value: draft.glucoseMgDl?.toDouble(),
                    step: 10,
                    min: 0,
                    max: 1000,
                    fallbackValue: 85,
                    unit: 'mg/dL',
                    onChanged: (double? value) {
                      if (value != null) {
                        viewModel.setGlucose(value.round());
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          AssessmentValidationSection(
            target: AssessmentValidationTarget.pupils,
            activeTarget: validationTarget,
            message: validationMessage,
            child: ExpansionTile(
              key: const Key('pupilResponseTile'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: const Text(
                '동공 반응',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                draft.leftPupil == null
                    ? '선택 입력'
                    : '좌 ${draft.leftPupil!.label} · 우 ${draft.rightPupil?.label ?? '-'}',
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<PupilResponse>(
                        key: const Key('leftPupilInput'),
                        initialValue: draft.leftPupil,
                        decoration: const InputDecoration(labelText: '좌측'),
                        items: PupilResponse.values
                            .map(
                              (PupilResponse value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: viewModel.setLeftPupil,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<PupilResponse>(
                        key: const Key('rightPupilInput'),
                        initialValue: draft.rightPupil,
                        decoration: const InputDecoration(labelText: '우측'),
                        items: PupilResponse.values
                            .map(
                              (PupilResponse value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: viewModel.setRightPupil,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Text(
              '과거력·알레르기·복용약',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('확인된 내용만 입력'),
            children: <Widget>[
              TextFormField(
                initialValue: draft.medicalHistory,
                decoration: const InputDecoration(hintText: '관련 과거력'),
                maxLength: 120,
                onChanged: viewModel.setMedicalHistory,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: draft.allergies,
                decoration: const InputDecoration(hintText: '알레르기'),
                maxLength: 120,
                onChanged: viewModel.setAllergies,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: draft.medications,
                decoration: const InputDecoration(hintText: '복용약'),
                maxLength: 120,
                onChanged: viewModel.setMedications,
              ),
            ],
          ),
          const Divider(),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Text(
              '감염·격리 우려',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(switch (draft.isolationConcern) {
              true => '있음',
              false => '없음',
              null => '선택 입력',
            }),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AssessmentChoice(
                      label: '있음',
                      selected: draft.isolationConcern == true,
                      onTap: () => viewModel.setIsolationConcern(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AssessmentChoice(
                      label: '없음',
                      selected: draft.isolationConcern == false,
                      onTap: () => viewModel.setIsolationConcern(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
