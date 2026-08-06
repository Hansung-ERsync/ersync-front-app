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
              ...draft.treatments
                  .where((TreatmentType value) => value != TreatmentType.none)
                  .map(
                    (TreatmentType type) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _TreatmentDetailsCard(
                        type: type,
                        entry:
                            draft.treatmentEntries[type] ??
                            const TreatmentEntryDraft(),
                        viewModel: viewModel,
                      ),
                    ),
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
        const AssessmentSectionTitle(title: '추가 입력', required: false),
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

class _TreatmentDetailsCard extends StatelessWidget {
  const _TreatmentDetailsCard({
    required this.type,
    required this.entry,
    required this.viewModel,
  });

  final TreatmentType type;
  final TreatmentEntryDraft entry;
  final PatientAssessmentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final List<_TreatmentFieldSpec> fields = _fieldsFor(type);
    return Container(
      key: Key('treatmentDetails_${type.apiValue}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${type.label} 상세',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _AssessmentDropdownField<TreatmentAttemptResult>(
            key: Key('treatmentResult_${type.apiValue}'),
            initialValue: entry.attemptResult,
            labelText: '처치 결과',
            items: TreatmentAttemptResult.values
                .map(
                  (TreatmentAttemptResult value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (TreatmentAttemptResult? value) {
              if (value != null) {
                viewModel.setTreatmentAttemptResult(type, value);
              }
            },
          ),
          ...fields.map(
            (_TreatmentFieldSpec field) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextFormField(
                key: Key('treatment_${type.apiValue}_${field.key}'),
                initialValue: entry.details[field.key] ?? '',
                keyboardType: field.numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                maxLength: field.maxLength,
                minLines: field.multiline ? 2 : 1,
                maxLines: field.multiline ? 3 : 1,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                ),
                onChanged: (String value) =>
                    viewModel.setTreatmentDetail(type, field.key, value),
              ),
            ),
          ),
          if (type == TreatmentType.cpr)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'CPR 시작 시각은 아래에서 선택하는 처치 시행 시각으로 기록됩니다.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  List<_TreatmentFieldSpec> _fieldsFor(TreatmentType type) {
    return switch (type) {
      TreatmentType.oxygen => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('method', '투여 방법', '예: MASK'),
        _TreatmentFieldSpec('flowRateLpm', '유량 (L/min)', '예: 5', numeric: true),
      ],
      TreatmentType.airway => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('device', '기도 확보 기구', '예: OPA'),
      ],
      TreatmentType.cpr => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('currentStatus', '현재 상태', '예: ONGOING'),
      ],
      TreatmentType.defibrillationAed => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('shockCount', '충격 횟수', '예: 1', numeric: true),
      ],
      TreatmentType.ivFluid => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('fluidName', '수액명', '예: NORMAL_SALINE'),
        _TreatmentFieldSpec('amountMl', '투여량 (mL)', '예: 500', numeric: true),
      ],
      TreatmentType.medication => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('medicationName', '약물명', '약물명을 입력하세요'),
        _TreatmentFieldSpec('dose', '용량', '예: 0.3mg'),
        _TreatmentFieldSpec('route', '투여 경로', '예: IM'),
      ],
      TreatmentType.bleedingWound ||
      TreatmentType.immobilization => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('method', '처치 방법', '처치 방법을 입력하세요'),
        _TreatmentFieldSpec('site', '처치 부위', '처치 부위를 입력하세요'),
      ],
      TreatmentType.ecg => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('leadType', '리드 종류', '예: 12_LEAD'),
      ],
      TreatmentType.warmingCooling => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('method', '처치 방법', '처치 방법을 입력하세요'),
      ],
      TreatmentType.delivery => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec('currentStatus', '현재 상태', '분만 현재 상태를 입력하세요'),
      ],
      TreatmentType.other => const <_TreatmentFieldSpec>[
        _TreatmentFieldSpec(
          'detail',
          '상세 내용',
          '시행한 처치를 입력하세요',
          multiline: true,
          maxLength: 200,
        ),
      ],
      TreatmentType.none => const <_TreatmentFieldSpec>[],
    };
  }
}

class _TreatmentFieldSpec {
  const _TreatmentFieldSpec(
    this.key,
    this.label,
    this.hint, {
    this.numeric = false,
    this.multiline = false,
    this.maxLength,
  });

  final String key;
  final String label;
  final String hint;
  final bool numeric;
  final bool multiline;
  final int? maxLength;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _PupilResponseField(
                        key: const Key('leftPupilInput'),
                        title: '좌측',
                        initialValue: draft.leftPupil,
                        onChanged: viewModel.setLeftPupil,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PupilResponseField(
                        key: const Key('rightPupilInput'),
                        title: '우측',
                        initialValue: draft.rightPupil,
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

class _PupilResponseField extends StatelessWidget {
  const _PupilResponseField({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onChanged,
  });

  final String title;
  final PupilResponse? initialValue;
  final ValueChanged<PupilResponse?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _AssessmentDropdownField<PupilResponse>(
          initialValue: initialValue,
          hintText: '선택',
          items: PupilResponse.values
              .map(
                (PupilResponse value) => DropdownMenuItem<PupilResponse>(
                  value: value,
                  child: Text(
                    value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AssessmentDropdownField<T> extends StatelessWidget {
  const _AssessmentDropdownField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      focusColor: AppColors.infoBackground,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 320,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(labelText: labelText, hintText: hintText),
      items: items,
      onChanged: onChanged,
    );
  }
}
