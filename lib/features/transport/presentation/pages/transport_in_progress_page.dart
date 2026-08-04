import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../patient_assessment/presentation/widgets/assessment_section.dart';
import '../../../patient_assessment/presentation/widgets/clinical_time_editor.dart';
import '../../../patient_assessment/presentation/widgets/numeric_stepper_field.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/transport_session.dart';
import '../providers/transport_view_model.dart';

class TransportInProgressPage extends ConsumerStatefulWidget {
  const TransportInProgressPage({super.key, required this.session});

  final TransportSession session;

  @override
  ConsumerState<TransportInProgressPage> createState() =>
      _TransportInProgressPageState();
}

class _TransportInProgressPageState
    extends ConsumerState<TransportInProgressPage> {
  late final TransportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(transportViewModelProvider.notifier);
    Future<void>.microtask(() => _viewModel.start(widget.session));
  }

  @override
  void dispose() {
    _viewModel.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              _TransportStatusBar(
                elapsedLabel: _formatElapsed(state.elapsedSeconds),
                etaLabel: widget.session.destination.etaLabel,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: <Widget>[
                    _DestinationHospitalCard(
                      session: widget.session,
                      onCall: _callHospital,
                    ),
                    const SizedBox(height: 18),
                    _PatientSummaryCard(summary: summary),
                    const SizedBox(height: 18),
                    _ClinicalUpdateCard(
                      isSaving: state.isSavingVitals,
                      onAddVitals: () => _addVitalUpdate(summary),
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
                  ],
                ),
              ),
              _HandoffBottomAction(
                isSubmitting: state.isRequestingHandoff,
                onPressed: _requestHandoff,
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
      context.goNamed('home');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인계 요청을 보내지 못했습니다. 다시 시도해주세요.')),
    );
  }

  String _formatElapsed(int elapsedSeconds) {
    final int minutes = elapsedSeconds ~/ 60;
    final int seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

class _HandoffBottomAction extends StatelessWidget {
  const _HandoffBottomAction({
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback onPressed;

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
      child: SizedBox(
        height: 56,
        child: FilledButton(
          key: const Key('requestHandoffButton'),
          onPressed: isSubmitting ? null : onPressed,
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

class _TransportStatusBar extends StatelessWidget {
  const _TransportStatusBar({
    required this.elapsedLabel,
    required this.etaLabel,
  });

  final String elapsedLabel;
  final String etaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Text('이송 진행 중', style: TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
            '$etaLabel · $elapsedLabel',
            key: const Key('transportElapsedTime'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationHospitalCard extends StatelessWidget {
  const _DestinationHospitalCard({required this.session, required this.onCall});

  final TransportSession session;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final hospital = session.destination;
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
            hospital.address,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _CompactInfo(
                icon: Icons.near_me_outlined,
                text: hospital.distanceLabel,
              ),
              const SizedBox(width: 14),
              _CompactInfo(
                icon: Icons.schedule_outlined,
                text: hospital.etaLabel,
              ),
            ],
          ),
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
                summary.vitalsMeasuredAt == null
                    ? '측정 시각 확인 불가'
                    : '최신 측정 ${formatClinicalTime(summary.vitalsMeasuredAt!)}',
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
    required this.isSaving,
    required this.onAddVitals,
  });

  final bool isSaving;
  final VoidCallback onAddVitals;

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
            '최신 상태를 수정해도 기존 측정 기록은 시간순으로 유지됩니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('addInTransitVitalsButton'),
              onPressed: isSaving ? null : onAddVitals,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('활력징후 수정'),
            ),
          ),
        ],
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
