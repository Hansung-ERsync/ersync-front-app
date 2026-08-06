import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/recent_transport.dart';

class HandoffStatusBadge extends StatelessWidget {
  const HandoffStatusBadge({super.key, required this.status});

  final HandoffStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = status == HandoffStatus.completed;
    final bool isCancelled = status == HandoffStatus.cancelled;
    final Color backgroundColor = isCancelled
        ? AppColors.negativeBackground
        : isCompleted
        ? AppColors.positiveBadgeBackground
        : AppColors.checkingBackground;
    final Color borderColor = isCancelled
        ? AppColors.negativeBorder
        : isCompleted
        ? AppColors.positiveBorder
        : AppColors.checkingBorder;
    final Color foregroundColor = isCancelled
        ? AppColors.statusNegative
        : isCompleted
        ? AppColors.statusPositive
        : AppColors.statusChecking;
    return Container(
      key: Key('handoffStatus_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        isCancelled
            ? '이송 취소'
            : isCompleted
            ? '인계 완료'
            : '인계 대기 중',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
