import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/recent_transport.dart';
import 'handoff_status_badge.dart';

class RecentTransportList extends StatelessWidget {
  const RecentTransportList({super.key, required this.transports});

  final List<RecentTransport> transports;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '최근 이송',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            children: List<Widget>.generate(transports.length, (int index) {
              final RecentTransport transport = transports[index];
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
                            transport.hospitalName,
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
                  if (index != transports.length - 1) const Divider(),
                ],
              );
            }),
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
