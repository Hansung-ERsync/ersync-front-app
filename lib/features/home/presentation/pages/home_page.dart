import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../settings/presentation/providers/app_guide_provider.dart';
import '../../../settings/presentation/widgets/app_guide_prompt_sheet.dart';
import '../providers/home_view_model.dart';
import '../widgets/new_patient_button.dart';
import '../widgets/recent_transport_list.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _guideCheckStarted = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HomeViewState> homeState = ref.watch(
      homeViewModelProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: homeState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) =>
              _HomeError(onLogin: () => context.goNamed('login')),
          data: (HomeViewState state) {
            _scheduleInitialGuide(state.user);
            return Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              state.user.organizationName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.user.displayName} 대원',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const Key('settingsButton'),
                        onPressed: () => context.pushNamed('settings'),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceMuted,
                          foregroundColor: AppColors.textSecondary,
                        ),
                        tooltip: '설정',
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 44,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  children: <Widget>[
                                    const SizedBox(height: 56),
                                    NewPatientButton(
                                      onPressed: () => context.pushNamed(
                                        'patientAssessment',
                                      ),
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 72),
                                    RecentTransportList(
                                      transports: state.recentTransports,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _scheduleInitialGuide(AuthUser user) {
    if (_guideCheckStarted) {
      return;
    }
    _guideCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialGuideIfNeeded(user);
    });
  }

  Future<void> _showInitialGuideIfNeeded(AuthUser user) async {
    final bool shouldShow;
    try {
      shouldShow = await ref.read(shouldShowAppGuideProvider)(user.username);
    } on Object {
      return;
    }
    if (!shouldShow || !mounted) {
      return;
    }

    final AppGuidePromptAction? action =
        await showModalBottomSheet<AppGuidePromptAction>(
          context: context,
          enableDrag: false,
          isDismissible: false,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => const AppGuidePromptSheet(),
        );
    await ref.read(markAppGuideSeenProvider)(user.username);
    if (action == AppGuidePromptAction.openGuide && mounted) {
      await context.pushNamed('appGuide');
    }
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textTertiary,
              size: 40,
            ),
            const SizedBox(height: 16),
            const Text('로그인이 필요합니다.'),
            const SizedBox(height: 20),
            FilledButton(onPressed: onLogin, child: const Text('로그인으로 이동')),
          ],
        ),
      ),
    );
  }
}
