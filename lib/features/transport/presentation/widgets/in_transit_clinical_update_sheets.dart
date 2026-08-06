import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../patient_assessment/domain/entities/assessment_enums.dart';
import '../../../patient_assessment/presentation/widgets/assessment_choice.dart';
import '../../domain/entities/patient_transport_summary.dart';

Future<InTransitConsciousnessSelection?> showInTransitConsciousnessSheet({
  required BuildContext context,
  required PatientTransportSummary summary,
}) {
  return showModalBottomSheet<InTransitConsciousnessSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ConsciousnessUpdateSheet(summary: summary),
  );
}

Future<InTransitPreKtasSelection?> showInTransitPreKtasSheet({
  required BuildContext context,
  required PatientTransportSummary summary,
}) {
  return showModalBottomSheet<InTransitPreKtasSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PreKtasUpdateSheet(summary: summary),
  );
}

Future<InTransitTreatmentSelection?> showInTransitTreatmentSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<InTransitTreatmentSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _TreatmentUpdateSheet(),
  );
}

class InTransitConsciousnessSelection {
  const InTransitConsciousnessSelection({
    required this.avpu,
    this.unassessableReason,
    this.unassessableDetail = '',
  });

  final AvpuLevel avpu;
  final UnassessableReason? unassessableReason;
  final String unassessableDetail;
}

class InTransitPreKtasSelection {
  const InTransitPreKtasSelection({
    required this.classificationStatus,
    this.level,
    this.exceptionReason,
    this.exceptionDetail = '',
  });

  final ClassificationStatus classificationStatus;
  final int? level;
  final EmergencyExceptionReason? exceptionReason;
  final String exceptionDetail;
}

class InTransitTreatmentSelection {
  const InTransitTreatmentSelection({
    required this.type,
    required this.attemptResult,
    required this.details,
  });

  final TreatmentType type;
  final TreatmentAttemptResult attemptResult;
  final Map<String, Object?> details;
}

class _ConsciousnessUpdateSheet extends StatefulWidget {
  const _ConsciousnessUpdateSheet({required this.summary});

  final PatientTransportSummary summary;

  @override
  State<_ConsciousnessUpdateSheet> createState() =>
      _ConsciousnessUpdateSheetState();
}

class _ConsciousnessUpdateSheetState extends State<_ConsciousnessUpdateSheet> {
  AvpuLevel? _avpu;
  UnassessableReason? _reason;
  String _detail = '';

  @override
  void initState() {
    super.initState();
    for (final AvpuLevel value in AvpuLevel.values) {
      if (value.apiValue == widget.summary.avpuLabel) {
        _avpu = value;
        break;
      }
    }
  }

  bool get _canContinue {
    if (_avpu == null) {
      return false;
    }
    if (_avpu != AvpuLevel.unassessable) {
      return true;
    }
    if (_reason == null) {
      return false;
    }
    return _reason != UnassessableReason.other || _detail.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return _UpdateSheetFrame(
      sheetKey: const Key('inTransitConsciousnessSheet'),
      title: '의식 상태 수정',
      description: '새로 관찰한 AVPU를 기록합니다. 이전 평가는 이력에 유지됩니다.',
      children: <Widget>[
        const _FieldTitle('의식 상태 (AVPU)'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AvpuLevel.values
              .map(
                (AvpuLevel value) => AssessmentChoice(
                  key: Key('inTransitAvpu_${value.apiValue}'),
                  label: '${value.label} (${value.apiValue})',
                  selected: _avpu == value,
                  selectedColor: value == AvpuLevel.unassessable
                      ? AppColors.statusUnavailable
                      : AppColors.primary,
                  onTap: () => setState(() {
                    _avpu = value;
                    if (value != AvpuLevel.unassessable) {
                      _reason = null;
                      _detail = '';
                    }
                  }),
                ),
              )
              .toList(),
        ),
        if (_avpu == AvpuLevel.unassessable) ...<Widget>[
          const SizedBox(height: 20),
          const _FieldTitle('평가 불가 사유'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UnassessableReason.values
                .map(
                  (UnassessableReason value) => AssessmentChoice(
                    key: Key('inTransitUnassessableReason_${value.apiValue}'),
                    label: value.label,
                    selected: _reason == value,
                    selectedColor: AppColors.statusUnavailable,
                    onTap: () => setState(() {
                      _reason = value;
                      if (value != UnassessableReason.other) {
                        _detail = '';
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          if (_reason == UnassessableReason.other) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('inTransitUnassessableDetailInput'),
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '기타 상세 사유',
                hintText: '평가할 수 없는 사유를 입력해주세요',
              ),
              onChanged: (String value) => setState(() => _detail = value),
            ),
          ],
        ],
        const SizedBox(height: 22),
        _ContinueButton(
          key: const Key('continueInTransitConsciousnessButton'),
          enabled: _canContinue,
          label: '관찰 시간 선택',
          onPressed: () => Navigator.of(context).pop(
            InTransitConsciousnessSelection(
              avpu: _avpu!,
              unassessableReason: _reason,
              unassessableDetail: _detail.trim(),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreKtasUpdateSheet extends StatefulWidget {
  const _PreKtasUpdateSheet({required this.summary});

  final PatientTransportSummary summary;

  @override
  State<_PreKtasUpdateSheet> createState() => _PreKtasUpdateSheetState();
}

class _PreKtasUpdateSheetState extends State<_PreKtasUpdateSheet> {
  ClassificationStatus? _status;
  int? _level;
  EmergencyExceptionReason? _reason;
  String _detail = '';

  @override
  void initState() {
    super.initState();
    final RegExpMatch? match = RegExp(
      r'[1-5]',
    ).firstMatch(widget.summary.preKtasLabel);
    if (match != null) {
      _status = ClassificationStatus.completed;
      _level = int.parse(match.group(0)!);
    } else if (widget.summary.preKtasLabel == '긴급 전송') {
      _status = ClassificationStatus.emergencyUnfinished;
    }
  }

  bool get _canContinue {
    if (_status == ClassificationStatus.completed) {
      return _level != null;
    }
    if (_status != ClassificationStatus.emergencyUnfinished ||
        _reason == null) {
      return false;
    }
    return _reason != EmergencyExceptionReason.other ||
        _detail.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return _UpdateSheetFrame(
      sheetKey: const Key('inTransitPreKtasSheet'),
      title: 'Pre-KTAS 수정',
      description: '환자 상태 변화에 따른 새 분류를 기록합니다. 이전 평가는 유지됩니다.',
      children: <Widget>[
        const _FieldTitle('분류 상태'),
        const SizedBox(height: 10),
        Row(
          children: ClassificationStatus.values
              .map(
                (ClassificationStatus value) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: value == ClassificationStatus.values.last ? 0 : 8,
                    ),
                    child: AssessmentChoice(
                      key: Key('inTransitPreKtasStatus_${value.apiValue}'),
                      label: value == ClassificationStatus.completed
                          ? '분류 완료'
                          : '긴급 전송',
                      selected: _status == value,
                      selectedColor:
                          value == ClassificationStatus.emergencyUnfinished
                          ? AppColors.statusRefused
                          : AppColors.primary,
                      onTap: () => setState(() {
                        _status = value;
                        _level = null;
                        _reason = null;
                        _detail = '';
                      }),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (_status == ClassificationStatus.completed) ...<Widget>[
          const SizedBox(height: 20),
          const _FieldTitle('Pre-KTAS 단계'),
          const SizedBox(height: 10),
          Row(
            children: List<Widget>.generate(5, (int index) {
              final int level = index + 1;
              final Color color = AppColors.preKtasButton(level);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: level == 5 ? 0 : 6),
                  child: Material(
                    color: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _level == level ? AppColors.primary : color,
                        width: _level == level ? 3 : 1,
                      ),
                    ),
                    child: InkWell(
                      key: Key('inTransitPreKtasLevel$level'),
                      onTap: () => setState(() => _level = level),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 56,
                        child: Center(
                          child: Text(
                            '$level',
                            style: TextStyle(
                              color: AppColors.onPreKtasButton(level),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ] else if (_status ==
            ClassificationStatus.emergencyUnfinished) ...<Widget>[
          const SizedBox(height: 20),
          const _FieldTitle('미완료 사유'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EmergencyExceptionReason.values
                .map(
                  (EmergencyExceptionReason value) => AssessmentChoice(
                    key: Key('inTransitEmergencyReason_${value.apiValue}'),
                    label: value.label,
                    selected: _reason == value,
                    selectedColor: AppColors.statusRefused,
                    onTap: () => setState(() {
                      _reason = value;
                      if (value != EmergencyExceptionReason.other) {
                        _detail = '';
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          if (_reason == EmergencyExceptionReason.other) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('inTransitEmergencyDetailInput'),
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '기타 상세 사유',
                hintText: '분류를 완료하지 못한 사유를 입력해주세요',
              ),
              onChanged: (String value) => setState(() => _detail = value),
            ),
          ],
        ],
        const SizedBox(height: 22),
        _ContinueButton(
          key: const Key('continueInTransitPreKtasButton'),
          enabled: _canContinue,
          label: _status == ClassificationStatus.completed
              ? '평가 시간 선택'
              : '이 상태로 기록',
          onPressed: () => Navigator.of(context).pop(
            InTransitPreKtasSelection(
              classificationStatus: _status!,
              level: _level,
              exceptionReason: _reason,
              exceptionDetail: _detail.trim(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TreatmentUpdateSheet extends StatefulWidget {
  const _TreatmentUpdateSheet();

  @override
  State<_TreatmentUpdateSheet> createState() => _TreatmentUpdateSheetState();
}

class _TreatmentUpdateSheetState extends State<_TreatmentUpdateSheet> {
  TreatmentType? _type;
  TreatmentAttemptResult? _attemptResult;
  final Map<String, String> _details = <String, String>{};

  List<_TreatmentFieldSpec> get _fields => switch (_type) {
    TreatmentType.oxygen => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('method', '산소 투여 방법', '예: 마스크'),
      _TreatmentFieldSpec('flowRateLpm', '유량 (L/min)', '예: 5', numeric: true),
    ],
    TreatmentType.airway => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('device', '기도 확보 기구', '예: OPA'),
    ],
    TreatmentType.cpr => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('currentStatus', '현재 CPR 상태', '예: 진행 중'),
    ],
    TreatmentType.defibrillationAed => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec(
        'shockCount',
        '충격 횟수',
        '예: 1',
        numeric: true,
        integer: true,
      ),
    ],
    TreatmentType.ivFluid => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('fluidName', '수액명', '예: 생리식염수'),
      _TreatmentFieldSpec('amountMl', '투여량 (mL)', '예: 500', numeric: true),
    ],
    TreatmentType.medication => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('medicationName', '약물명', '약물명을 입력하세요'),
      _TreatmentFieldSpec('dose', '용량', '예: 0.3 mg'),
      _TreatmentFieldSpec('route', '투여 경로', '예: IM'),
    ],
    TreatmentType.bleedingWound ||
    TreatmentType.immobilization => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('method', '처치 방법', '처치 방법을 입력하세요'),
      _TreatmentFieldSpec('site', '처치 부위', '처치 부위를 입력하세요'),
    ],
    TreatmentType.ecg => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('leadType', '유도 종류', '예: 12유도'),
    ],
    TreatmentType.warmingCooling => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('method', '적용 방법', '예: 보온포 적용'),
    ],
    TreatmentType.delivery => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('currentStatus', '분만 상태', '현재 상태를 입력하세요'),
    ],
    TreatmentType.other => const <_TreatmentFieldSpec>[
      _TreatmentFieldSpec('detail', '기타 처치 내용', '처치 내용을 입력하세요', maxLength: 300),
    ],
    TreatmentType.none || null => const <_TreatmentFieldSpec>[],
  };

  bool get _canContinue {
    if (_type == null || _attemptResult == null || _fields.isEmpty) {
      return false;
    }
    for (final _TreatmentFieldSpec field in _fields) {
      final String value = _details[field.key]?.trim() ?? '';
      if (value.isEmpty) {
        return false;
      }
      if (field.numeric) {
        final num? parsed = num.tryParse(value);
        if (parsed == null || parsed < 0) {
          return false;
        }
        if (field.integer && parsed != parsed.round()) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, Object?> _normalizedDetails() {
    return <String, Object?>{
      for (final _TreatmentFieldSpec field in _fields)
        field.key: field.numeric
            ? (field.integer
                  ? int.parse(_details[field.key]!.trim())
                  : num.parse(_details[field.key]!.trim()))
            : _details[field.key]!.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _UpdateSheetFrame(
      sheetKey: const Key('inTransitTreatmentSheet'),
      title: '처치 기록 추가',
      description: '새로 시행했거나 실패한 처치 시도 한 건을 기록합니다.',
      children: <Widget>[
        const _FieldTitle('처치 유형'),
        const SizedBox(height: 10),
        DropdownButtonFormField<TreatmentType>(
          key: const Key('inTransitTreatmentTypeDropdown'),
          initialValue: _type,
          decoration: const InputDecoration(hintText: '처치 유형을 선택해주세요'),
          items: TreatmentType.values
              .where((TreatmentType value) => value != TreatmentType.none)
              .map(
                (TreatmentType value) => DropdownMenuItem<TreatmentType>(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (TreatmentType? value) => setState(() {
            _type = value;
            _details.clear();
          }),
        ),
        const SizedBox(height: 20),
        const _FieldTitle('처치 결과'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TreatmentAttemptResult.values
              .map(
                (TreatmentAttemptResult value) => AssessmentChoice(
                  key: Key('inTransitTreatmentResult_${value.apiValue}'),
                  label: value.label,
                  selected: _attemptResult == value,
                  onTap: () => setState(() => _attemptResult = value),
                ),
              )
              .toList(),
        ),
        if (_type != null) ...<Widget>[
          const SizedBox(height: 20),
          ..._fields.map(
            (_TreatmentFieldSpec field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: Key('inTransitTreatmentField_${field.key}'),
                initialValue: _details[field.key],
                keyboardType: field.numeric
                    ? TextInputType.numberWithOptions(decimal: !field.integer)
                    : TextInputType.text,
                inputFormatters: field.numeric
                    ? <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          field.integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
                        ),
                      ]
                    : null,
                maxLength: field.maxLength,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                ),
                onChanged: (String value) => setState(() {
                  _details[field.key] = value;
                }),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _ContinueButton(
          key: const Key('continueInTransitTreatmentButton'),
          enabled: _canContinue,
          label: '처치 시간 선택',
          onPressed: () => Navigator.of(context).pop(
            InTransitTreatmentSelection(
              type: _type!,
              attemptResult: _attemptResult!,
              details: _normalizedDetails(),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateSheetFrame extends StatelessWidget {
  const _UpdateSheetFrame({
    required this.sheetKey,
    required this.title,
    required this.description,
    required this.children,
  });

  final Key sheetKey;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListView(
            key: sheetKey,
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    tooltip: '닫기',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontWeight: FontWeight.w800));
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    super.key,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      ),
    );
  }
}

class _TreatmentFieldSpec {
  const _TreatmentFieldSpec(
    this.key,
    this.label,
    this.hint, {
    this.numeric = false,
    this.integer = false,
    this.maxLength = 100,
  });

  final String key;
  final String label;
  final String hint;
  final bool numeric;
  final bool integer;
  final int maxLength;
}
