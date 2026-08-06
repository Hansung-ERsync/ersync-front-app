import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';
import 'assessment_section.dart';

class OnsetTimeSelection {
  const OnsetTimeSelection({required this.status, required this.occurredAt});

  final ClinicalTimeStatus status;
  final DateTime? occurredAt;
}

class _ClinicalTimePickerResult {
  const _ClinicalTimePickerResult({required this.time, this.onsetStatus});

  final DateTime? time;
  final ClinicalTimeStatus? onsetStatus;
}

Future<DateTime?> showClinicalTimePickerSheet({
  required BuildContext context,
  required String title,
  required DateTime initialTime,
  String? description,
  Key? sheetKey,
  Key? confirmButtonKey,
}) {
  return showModalBottomSheet<_ClinicalTimePickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => _ClinicalTimePickerSheet(
      title: title,
      description: description,
      initialTime: initialTime,
      sheetKey: sheetKey,
      confirmButtonKey: confirmButtonKey,
    ),
  ).then((_ClinicalTimePickerResult? result) => result?.time);
}

Future<OnsetTimeSelection?> showOnsetTimePickerSheet({
  required BuildContext context,
  required DateTime initialTime,
  ClinicalTimeStatus? initialStatus,
  Key? sheetKey,
  Key? confirmButtonKey,
}) async {
  final _ClinicalTimePickerResult? result =
      await showModalBottomSheet<_ClinicalTimePickerResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) => _ClinicalTimePickerSheet(
          title: '증상 발생 시각을 선택해주세요',
          description: '정확한 시각을 고르거나 아래에서 추정·확인 불가로 기록합니다.',
          initialTime: initialTime,
          initialOnsetStatus: initialStatus,
          sheetKey: sheetKey,
          confirmButtonKey: confirmButtonKey,
        ),
      );
  final ClinicalTimeStatus? status = result?.onsetStatus;
  if (result == null || status == null) {
    return null;
  }
  return OnsetTimeSelection(status: status, occurredAt: result.time);
}

class _ClinicalTimePickerSheet extends StatefulWidget {
  const _ClinicalTimePickerSheet({
    required this.title,
    required this.initialTime,
    this.description,
    this.initialOnsetStatus,
    this.sheetKey,
    this.confirmButtonKey,
  });

  final String title;
  final String? description;
  final DateTime initialTime;
  final ClinicalTimeStatus? initialOnsetStatus;
  final Key? sheetKey;
  final Key? confirmButtonKey;

  @override
  State<_ClinicalTimePickerSheet> createState() =>
      _ClinicalTimePickerSheetState();
}

class _ClinicalTimePickerSheetState extends State<_ClinicalTimePickerSheet> {
  late DateTime _selectedTime;
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late FixedExtentScrollController _periodController;
  late int _periodIndex;
  bool _showDirectInput = false;
  ClinicalTimeStatus? _onsetStatus;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    _onsetStatus = widget.initialOnsetStatus == ClinicalTimeStatus.unknown
        ? ClinicalTimeStatus.unknown
        : widget.initialOnsetStatus ?? ClinicalTimeStatus.exact;
    _periodIndex = widget.initialTime.hour >= 12 ? 1 : 0;
    _periodController = FixedExtentScrollController(initialItem: _periodIndex);
    _hourController = TextEditingController(
      text: _hour12(widget.initialTime.hour).toString(),
    );
    _minuteController = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnsetMode =
        widget.initialOnsetStatus != null || widget.title == '증상 발생 시각을 선택해주세요';
    final bool isUnknown =
        isOnsetMode && _onsetStatus == ClinicalTimeStatus.unknown;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: widget.sheetKey,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('closeClinicalTimeSheetButton'),
                  onPressed: Navigator.of(context).pop,
                  tooltip: '닫기',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (widget.description != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                widget.description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.infoBackground,
                border: Border.all(color: AppColors.infoBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                isUnknown
                    ? '증상 발생 시각 확인 불가'
                    : formatClinicalTime(_selectedTime),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimeOptionButton(
                    label: '지금',
                    onPressed: () => _selectQuick(Duration.zero),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TimeOptionButton(
                    label: '5분 전',
                    onPressed: () => _selectQuick(const Duration(minutes: 5)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TimeOptionButton(
                    label: '10분 전',
                    onPressed: () => _selectQuick(const Duration(minutes: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TimeOptionButton(
                    key: const Key('directClinicalTimeButton'),
                    label: '직접 선택',
                    selected: _showDirectInput,
                    onPressed: _openDirectInput,
                  ),
                ),
              ],
            ),
            if (isOnsetMode) ...<Widget>[
              const SizedBox(height: 18),
              const Text(
                '시각을 정확히 알 수 없나요?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeStatusButton(
                      key: const Key('estimatedOnsetTimeButton'),
                      label: '추정 시각',
                      icon: Icons.approval_outlined,
                      selected: _onsetStatus == ClinicalTimeStatus.estimated,
                      onPressed: () => setState(() {
                        _onsetStatus = ClinicalTimeStatus.estimated;
                        _showDirectInput = false;
                        _inputError = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimeStatusButton(
                      key: const Key('unknownOnsetTimeButton'),
                      label: '확인 불가',
                      icon: Icons.help_outline_rounded,
                      selected: _onsetStatus == ClinicalTimeStatus.unknown,
                      onPressed: () => setState(() {
                        _onsetStatus = ClinicalTimeStatus.unknown;
                        _showDirectInput = false;
                        _inputError = null;
                      }),
                    ),
                  ),
                ],
              ),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: !_showDirectInput
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const Key('directClinicalTimeInput'),
                      padding: const EdgeInsets.only(top: 18),
                      child: _buildDirectInput(context),
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                key:
                    widget.confirmButtonKey ??
                    const Key('applyClinicalTimeButton'),
                onPressed: _apply,
                child: Text(isUnknown ? '확인 불가로 적용' : '이 시간으로 적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('시간 직접 입력', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 76,
                height: 116,
                child: CupertinoPicker(
                  key: const Key('clinicalTimePeriodPicker'),
                  scrollController: _periodController,
                  itemExtent: 42,
                  useMagnifier: true,
                  magnification: 1.08,
                  selectionOverlay: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _periodIndex = index;
                      _inputError = null;
                    });
                  },
                  children: const <Widget>[
                    Center(child: Text('오전')),
                    Center(child: Text('오후')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('clinicalTimeHourInput'),
                  controller: _hourController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: '시',
                    hintText: '1~12',
                  ),
                  onChanged: (_) => setState(() => _inputError = null),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('clinicalTimeMinuteInput'),
                  controller: _minuteController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: '분',
                    hintText: '0~59',
                  ),
                  onChanged: (_) => setState(() => _inputError = null),
                ),
              ),
            ],
          ),
          if (_inputError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _inputError!,
              key: const Key('clinicalTimeInputError'),
              style: const TextStyle(
                color: AppColors.statusNegative,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _selectQuick(Duration offset) {
    setState(() {
      _selectedTime = DateTime.now().subtract(offset);
      if (_onsetStatus == ClinicalTimeStatus.unknown) {
        _onsetStatus = ClinicalTimeStatus.exact;
      }
      _showDirectInput = false;
      _inputError = null;
    });
  }

  void _openDirectInput() {
    setState(() {
      _showDirectInput = true;
      if (_onsetStatus == ClinicalTimeStatus.unknown) {
        _onsetStatus = ClinicalTimeStatus.exact;
      }
      _inputError = null;
    });
  }

  void _apply() {
    if (_onsetStatus == ClinicalTimeStatus.unknown) {
      Navigator.of(context).pop(
        const _ClinicalTimePickerResult(
          time: null,
          onsetStatus: ClinicalTimeStatus.unknown,
        ),
      );
      return;
    }
    if (_showDirectInput && !_updateFromDirectInput()) {
      return;
    }
    Navigator.of(context).pop(
      _ClinicalTimePickerResult(time: _selectedTime, onsetStatus: _onsetStatus),
    );
  }

  bool _updateFromDirectInput() {
    final int? hour = int.tryParse(_hourController.text);
    final int? minute = int.tryParse(_minuteController.text);
    if (hour == null || hour < 1 || hour > 12) {
      setState(() => _inputError = '시는 1~12 사이로 입력해주세요.');
      return false;
    }
    if (minute == null || minute < 0 || minute > 59) {
      setState(() => _inputError = '분은 0~59 사이로 입력해주세요.');
      return false;
    }

    final int hour24 = _periodIndex == 0 ? hour % 12 : (hour % 12) + 12;
    final DateTime now = DateTime.now();
    final DateTime selected = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      minute,
    );
    if (selected.isAfter(now)) {
      setState(() => _inputError = '현재 시간 이후는 선택할 수 없습니다.');
      return false;
    }
    _selectedTime = selected;
    return true;
  }

  int _hour12(int hour) {
    final int converted = hour % 12;
    return converted == 0 ? 12 : converted;
  }
}

class _TimeOptionButton extends StatelessWidget {
  const _TimeOptionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.textOnDark : AppColors.primary,
        backgroundColor: selected ? AppColors.primary : AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}

class _TimeStatusButton extends StatelessWidget {
  const _TimeStatusButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.textOnDark : AppColors.primary,
        backgroundColor: selected ? AppColors.primary : AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        minimumSize: const Size(0, 48),
      ),
    );
  }
}
