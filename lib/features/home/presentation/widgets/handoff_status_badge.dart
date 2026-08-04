import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/recent_transport.dart';

class HandoffStatusBadge extends StatelessWidget {
  const HandoffStatusBadge({super.key, required this.status});

  final HandoffStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = status == HandoffStatus.completed;
    return Container(
      key: Key('handoffStatus_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.positiveBadgeBackground
            : AppColors.checkingBackground,
        border: Border.all(
          color: isCompleted
              ? AppColors.positiveBorder
              : AppColors.checkingBorder,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        isCompleted ? '인계 완료' : '인계 대기 중',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isCompleted
              ? AppColors.statusPositive
              : AppColors.statusChecking,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
