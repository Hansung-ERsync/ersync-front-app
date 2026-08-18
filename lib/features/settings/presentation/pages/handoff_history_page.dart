import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/providers/home_view_model.dart';
import '../../../home/presentation/widgets/recent_transport_list.dart';

class HandoffHistoryPage extends ConsumerWidget {
  const HandoffHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeViewState> state = ref.watch(homeViewModelProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(centerTitle: true, title: const Text('인계 기록')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('인계 기록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.'),
          ),
        ),
        data: (HomeViewState value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeViewModelProvider);
            await ref.read(homeViewModelProvider.future);
          },
          child: ListView(
            key: const Key('handoffHistoryList'),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              RecentTransportList(
                transports: value.recentTransports,
                maximumItems: null,
                title: '전체 인계 기록',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
