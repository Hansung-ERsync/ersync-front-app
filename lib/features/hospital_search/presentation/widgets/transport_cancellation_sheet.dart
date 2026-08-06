import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/hospital_search_progress.dart';

Future<TransportCancellation?> showTransportCancellationSheet(
  BuildContext context,
) {
  return showModalBottomSheet<TransportCancellation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const TransportCancellationSheet(),
  );
}

class TransportCancellationSheet extends StatefulWidget {
  const TransportCancellationSheet({super.key});

  @override
  State<TransportCancellationSheet> createState() =>
      _TransportCancellationSheetState();
}

class _TransportCancellationSheetState
    extends State<TransportCancellationSheet> {
  TransportCancellationReason? _selectedReason;
  String _detail = '';

  bool get _canSubmit {
    final TransportCancellationReason? reason = _selectedReason;
    if (reason == null) {
      return false;
    }
    return reason != TransportCancellationReason.other ||
        _detail.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('transportCancellationSheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '이송 요청을 취소할까요?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: Navigator.of(context).pop,
                tooltip: '닫기',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '취소 후에는 같은 요청을 다시 진행할 수 없습니다. 취소 사유를 선택해주세요.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          ...TransportCancellationReason.values.map(
            (TransportCancellationReason reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _selectedReason == reason
                    ? AppColors.negativeBackground
                    : AppColors.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: _selectedReason == reason
                        ? AppColors.negativeBorder
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  key: Key('cancellationReason_${reason.apiValue}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _selectedReason = reason;
                    if (reason != TransportCancellationReason.other) {
                      _detail = '';
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _selectedReason == reason
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _selectedReason == reason
                              ? AppColors.statusNegative
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          reason.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_selectedReason == TransportCancellationReason.other) ...<Widget>[
            const SizedBox(height: 4),
            TextFormField(
              key: const Key('cancellationDetailInput'),
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '상세 사유',
                hintText: '기타 취소 사유를 입력해주세요',
              ),
              onChanged: (String value) => setState(() => _detail = value),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: const Key('confirmTransportCancellationButton'),
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop(
                      TransportCancellation(
                        reason: _selectedReason!,
                        detail: _detail,
                      ),
                    )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusNegative,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('요청 취소하기'),
            ),
          ),
        ],
      ),
    );
  }
}
