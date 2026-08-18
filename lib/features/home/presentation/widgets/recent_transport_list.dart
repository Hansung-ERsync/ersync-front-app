import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/recent_transport.dart';
import 'handoff_status_badge.dart';

class RecentTransportList extends StatelessWidget {
  const RecentTransportList({
    super.key,
    required this.transports,
    this.maximumItems = 3,
    this.title = '최근 이송',
  });

  final List<RecentTransport> transports;
  final int? maximumItems;
  final String title;

  @override
  Widget build(BuildContext context) {
    final List<RecentTransport> visibleTransports = maximumItems == null
        ? transports
        : transports.take(maximumItems!).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (transports.isEmpty)
          const _EmptyRecentTransportCard()
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              children: <Widget>[
                ...List<Widget>.generate(visibleTransports.length, (int index) {
                  final RecentTransport transport = visibleTransports[index];
                  return Column(
                    children: <Widget>[
                      Padding(
                        key: Key('recentTransport_${transport.requestId}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                transport.hospitalDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatStatusTime(transport.statusUpdatedAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                            const SizedBox(width: 8),
                            HandoffStatusBadge(status: transport.handoffStatus),
                          ],
                        ),
                      ),
                      if (index != visibleTransports.length - 1)
                        const Divider(),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  String _formatStatusTime(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime date = DateTime(value.year, value.month, value.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    if (date == today) {
      return '오늘 $hour:$minute';
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return '어제 $hour:$minute';
    }
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}

class _EmptyRecentTransportCard extends StatelessWidget {
  const _EmptyRecentTransportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('recentTransportsEmptyState'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              color: AppColors.textTertiary,
              size: 23,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '아직 최근 이송이 없습니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '인계 요청·완료 또는 취소된 이송이 여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
