import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import '../../../settings/presentation/providers/app_guide_provider.dart';
import '../../../settings/presentation/widgets/app_guide_prompt_sheet.dart';
import '../../../transport/domain/entities/active_transport_recovery.dart';
import '../../../transport/presentation/providers/transport_view_model.dart';
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
  bool _activeRecoveryCheckStarted = false;
  bool _activeRecoveryResolved = false;
  String? _activeRecoveryError;
  bool _isStartingNewPatient = false;

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
            _scheduleActiveRecovery(state.user);
            if (_activeRecoveryError != null) {
              return _ActiveRecoveryError(
                message: _activeRecoveryError!,
                onRetry: () => _retryActiveRecovery(state.user),
              );
            }
            if (_activeRecoveryResolved) {
              _scheduleInitialGuide(state.user);
            }
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
                                      onPressed: _isStartingNewPatient
                                          ? null
                                          : _startNewPatient,
                                      isLoading: _isStartingNewPatient,
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

  void _scheduleActiveRecovery(AuthUser user) {
    if (_activeRecoveryCheckStarted) {
      return;
    }
    _activeRecoveryCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverActiveTransport(user);
    });
  }

  Future<void> _recoverActiveTransport(AuthUser user) async {
    final ActiveTransportRecovery? recovery;
    try {
      recovery = await ref
          .read(transportRepositoryProvider)
          .recoverActiveTransport();
    } on Object {
      if (mounted) {
        setState(() {
          _activeRecoveryError =
              '진행 중 이송 상태를 확인하지 못했습니다. 네트워크를 확인하고 다시 시도해주세요.';
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final searchSession = recovery?.searchSession;
    if (searchSession != null) {
      context.goNamed(
        'hospitalSearch',
        pathParameters: <String, String>{'requestId': searchSession.requestId},
        extra: searchSession,
      );
      return;
    }
    final transportSession = recovery?.transportSession;
    if (transportSession != null) {
      context.goNamed(
        'transportInProgress',
        pathParameters: <String, String>{
          'requestId': transportSession.requestId,
        },
        extra: transportSession,
      );
      return;
    }
    setState(() => _activeRecoveryResolved = true);
    _scheduleInitialGuide(user);
  }

  void _retryActiveRecovery(AuthUser user) {
    setState(() => _activeRecoveryError = null);
    _recoverActiveTransport(user);
  }

  Future<void> _startNewPatient() async {
    if (_isStartingNewPatient) {
      return;
    }
    setState(() => _isStartingNewPatient = true);
    // A cancelled/completed transport clears its draft at that command's
    // success boundary. Otherwise keep the secure local draft so an app
    // restart or temporary network failure can resume the same request key.
    try {
      ref.invalidate(patientAssessmentViewModelProvider);
      if (mounted) {
        // Navigate immediately and let the assessment page show its loading
        // state while protocol/GPS initialization finishes. Invalidation
        // prevents the previous patient's last step from flashing.
        await context.pushNamed('patientAssessment');
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingNewPatient = false);
      }
    }
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

class _ActiveRecoveryError extends StatelessWidget {
  const _ActiveRecoveryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.sync_problem_rounded,
              color: AppColors.statusChecking,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('retryActiveTransportRecoveryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('진행 중 이송 다시 확인'),
            ),
          ],
        ),
      ),
    );
  }
}
