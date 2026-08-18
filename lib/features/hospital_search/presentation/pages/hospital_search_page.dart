import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/transport_session.dart';
import '../../../patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import '../../domain/entities/accepted_hospital.dart';
import '../../domain/entities/hospital_response.dart';
import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';
import '../providers/hospital_search_view_model.dart';
import '../widgets/transport_cancellation_sheet.dart';

const int initialHospitalSearchAnimationSeconds = 10;

bool shouldShowHospitalResponseDashboard({
  required HospitalSearchSession session,
  required HospitalSearchProgress progress,
}) {
  return session.isDestinationRecovery ||
      progress.hasResponseDashboard ||
      progress.elapsedSeconds >= initialHospitalSearchAnimationSeconds;
}

class HospitalSearchPage extends ConsumerStatefulWidget {
  const HospitalSearchPage({super.key, required this.session});

  final HospitalSearchSession session;

  @override
  ConsumerState<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends ConsumerState<HospitalSearchPage>
    with WidgetsBindingObserver {
  late final HospitalSearchViewModel _viewModel;
  bool _isLeavingCancelledRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ref.read(hospitalSearchViewModelProvider.notifier);
    Future<void>.microtask(() => _viewModel.start(widget.session));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _viewModel.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _viewModel.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final HospitalSearchViewState observedState = ref.watch(
      hospitalSearchViewModelProvider,
    );
    // The provider is shared across routes. Ignore a previous request's state
    // until start() installs this page's request, especially its cancelled flag.
    final HospitalSearchViewState state =
        observedState.session?.requestId == widget.session.requestId
        ? observedState
        : const HospitalSearchViewState();
    final HospitalSearchProgress progress =
        state.progress ??
        HospitalSearchProgress(
          requestId: widget.session.requestId,
          currentRadiusKm: widget.session.initialRadiusKm,
          elapsedSeconds: 0,
        );

    if (state.isCancelled) {
      _scheduleCancelledRequestExit();
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 44,
                  color: AppColors.statusPositive,
                ),
                SizedBox(height: 14),
                Text(
                  '요청 취소 완료',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (shouldShowHospitalResponseDashboard(
      session: widget.session,
      progress: progress,
    )) {
      return _buildHospitalResponsesScreen(state, progress);
    }

    final int declinedCount =
        progress.rejectedHospitals.length + progress.withdrawnHospitals.length;
    final int visibleResponseCount =
        progress.pendingHospitals.length + declinedCount;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: <Widget>[
                            const _SendingIcon(),
                            const SizedBox(height: 28),
                            Text(
                              '요청 전송 중',
                              key: const Key('hospitalSearchTitle'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              '요청 경과 시간',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatElapsed(progress.elapsedSeconds),
                              key: const Key('hospitalSearchElapsedTime'),
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -1.5,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchGuidance(progress),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            if (visibleResponseCount > 0) ...<Widget>[
                              const SizedBox(height: 18),
                              Container(
                                key: const Key(
                                  'hospitalSearchLiveResponseSummary',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '응답 대기 ${progress.pendingHospitals.length} · '
                                  '거절 $declinedCount',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            if (state.errorMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Text(
                                state.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.statusNegative,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    key: const Key('cancelTransportRequestButton'),
                    onPressed: state.isCancelling
                        ? null
                        : _openCancellationSheet,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.statusNegative,
                      foregroundColor: AppColors.textOnDark,
                      disabledBackgroundColor: AppColors.negativeBorder,
                      disabledForegroundColor: AppColors.textOnDark,
                    ),
                    child: state.isCancelling
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.textOnDark,
                            ),
                          )
                        : const Text(
                            '요청 취소',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalResponsesScreen(
    HospitalSearchViewState state,
    HospitalSearchProgress progress,
  ) {
    final List<HospitalResponse> declinedHospitals = <HospitalResponse>[
      ...progress.withdrawnHospitals,
      ...progress.rejectedHospitals,
    ];
    return PopScope(
      canPop: false,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _AcceptedStatusBar(
                  elapsedLabel: _formatElapsed(progress.elapsedSeconds),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '병원 응답 현황',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      _HospitalResponseTabs(
                        acceptedCount: progress.acceptedHospitals.length,
                        pendingCount: progress.pendingHospitals.length,
                        declinedCount: declinedHospitals.length,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _HospitalResponseList(
                        listKey: const Key('acceptedHospitalList'),
                        emptyTitle: '아직 수락한 병원이 없습니다',
                        emptyDescription: '수락한 병원이 이 화면에 바로 표시됩니다.',
                        children: progress.acceptedHospitals
                            .map(
                              (AcceptedHospital hospital) =>
                                  _AcceptedHospitalCard(
                                    hospital: hospital,
                                    isSelecting: state.isSelectingDestination,
                                    onCall: () => _callHospital(hospital),
                                    onDirections: () =>
                                        _openDirections(hospital),
                                    onSelect: () =>
                                        _selectDestination(hospital),
                                  ),
                            )
                            .toList(),
                      ),
                      _HospitalResponseList(
                        listKey: const Key('pendingHospitalList'),
                        emptyTitle: '응답을 기다리는 병원이 없습니다',
                        emptyDescription: '응답 대기 중인 병원이 이 화면에 바로 표시됩니다.',
                        children: progress.pendingHospitals
                            .map(
                              (HospitalResponse hospital) =>
                                  _HospitalResponseCard(hospital: hospital),
                            )
                            .toList(),
                      ),
                      _HospitalResponseList(
                        listKey: const Key('declinedHospitalList'),
                        emptyTitle: '거절하거나 철회한 병원이 없습니다',
                        emptyDescription: '거절하거나 철회한 병원이 이 화면에 바로 표시됩니다.',
                        children: declinedHospitals
                            .map(
                              (HospitalResponse hospital) =>
                                  _HospitalResponseCard(hospital: hospital),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.statusNegative,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Container(
                  key: const Key('acceptedHospitalBottomAction'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      key: const Key('cancelAcceptedTransportButton'),
                      onPressed: state.isSelectingDestination
                          ? null
                          : _openCancellationSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusNegative,
                        foregroundColor: AppColors.textOnDark,
                        disabledBackgroundColor: AppColors.negativeBorder,
                        disabledForegroundColor: AppColors.textOnDark,
                      ),
                      child: const Text(
                        '요청 취소',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDestination(AcceptedHospital hospital) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          barrierColor: AppColors.scrim,
          builder: (_) => _ConfirmActionDialog(
            dialogKey: const Key('confirmDestinationDialog'),
            title: '${hospital.name}으로\n이송할까요?',
            description: '선택하면 해당 병원에 목적지 확정과 이송 시작 상태가 전달됩니다.',
            cancelLabel: '취소',
            confirmLabel: '병원으로 이송',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final bool selected = await _viewModel.selectDestination(hospital);
    if (!selected || !mounted) {
      return;
    }
    context.goNamed(
      'transportInProgress',
      pathParameters: <String, String>{'requestId': widget.session.requestId},
      extra: TransportSession(
        requestId: widget.session.requestId,
        requestStartedAt: widget.session.startedAt,
        destination: hospital,
        patientSummary: widget.session.patientSummary,
      ),
    );
  }

  Future<void> _callHospital(AcceptedHospital hospital) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: hospital.emergencyRoomPhone.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    bool opened = false;
    try {
      opened = await launchUrl(phoneUri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('전화 앱을 열 수 없습니다.')));
    }
  }

  Future<void> _openDirections(AcceptedHospital hospital) async {
    final double? latitude = hospital.latitude;
    final double? longitude = hospital.longitude;
    if (latitude == null || longitude == null) {
      return;
    }
    final Uri directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{'api': '1', 'destination': '$latitude,$longitude'},
    );
    bool opened = false;
    try {
      opened = await launchUrl(
        directionsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지도 앱을 열 수 없습니다.')));
    }
  }

  Future<void> _openCancellationSheet() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          barrierColor: AppColors.scrim,
          builder: (_) => const _ConfirmActionDialog(
            dialogKey: Key('confirmRequestCancellationDialog'),
            title: '이송 요청을\n취소할까요?',
            description: '취소한 요청은 다시 진행할 수 없습니다. 계속하면 취소 사유를 선택합니다.',
            cancelLabel: '돌아가기',
            confirmLabel: '취소하기',
            destructive: true,
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final TransportCancellation? cancellation =
        await showTransportCancellationSheet(context);
    if (cancellation == null || !mounted) {
      return;
    }
    await _viewModel.cancel(cancellation);
  }

  void _scheduleCancelledRequestExit() {
    if (_isLeavingCancelledRequest) {
      return;
    }
    _isLeavingCancelledRequest = true;
    final clearDraft = ref.read(clearPatientAssessmentDraftProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        ref.invalidate(patientAssessmentViewModelProvider);
        await clearDraft.call();
      } finally {
        if (mounted) {
          ref.invalidate(patientAssessmentViewModelProvider);
          context.goNamed('home');
        }
      }
    });
  }

  String _formatElapsed(int elapsedSeconds) {
    final int minutes = elapsedSeconds ~/ 60;
    final int seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int seconds) {
    if (seconds % 60 == 0) {
      return '${seconds ~/ 60}분';
    }
    return '$seconds초';
  }

  String _searchGuidance(HospitalSearchProgress progress) {
    if (progress.currentRadiusKm >= widget.session.maximumRadiusKm &&
        progress.nextExpansionAt == null) {
      return '최대 탐색 범위에서 병원 응답을 계속 기다리고 있습니다.';
    }
    if (progress.candidateShortage) {
      return '현재 범위의 병원 수가 부족해 다음 범위로 확대하고 있습니다.';
    }
    return '${_formatMinutes(widget.session.expansionIntervalSeconds)} 미응답 시 '
        '${widget.session.radiusStepKm}km씩 자동 확대됩니다.';
  }
}

class _SendingIcon extends StatefulWidget {
  const _SendingIcon();

  @override
  State<_SendingIcon> createState() => _SendingIconState();
}

class _SendingIconState extends State<_SendingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const Key('hospitalSearchRadar'),
      dimension: 210,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (int index = 0; index < 3; index++)
                _RadarRing(progress: (_controller.value + index / 3) % 1),
              child!,
            ],
          );
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x30101828),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.phone_in_talk_outlined,
            color: AppColors.textOnDark,
            size: 42,
          ),
        ),
      ),
    );
  }
}

class _RadarRing extends StatelessWidget {
  const _RadarRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double size = 92 + 112 * Curves.easeOut.transform(progress);
    return Opacity(
      opacity: (1 - progress).clamp(0, 1),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.infoBackground.withValues(alpha: 0.24),
          border: Border.all(
            color: AppColors.statusInfo.withValues(
              alpha: 0.34 * (1 - progress),
            ),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _HospitalResponseTabs extends StatelessWidget {
  const _HospitalResponseTabs({
    required this.acceptedCount,
    required this.pendingCount,
    required this.declinedCount,
  });

  final int acceptedCount;
  final int pendingCount;
  final int declinedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        key: const Key('hospitalResponseTabs'),
        dividerColor: Colors.transparent,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x0D101828), blurRadius: 6),
          ],
        ),
        tabs: <Widget>[
          Tab(text: '수락 $acceptedCount'),
          Tab(text: '응답 대기 $pendingCount'),
          Tab(text: '거절 $declinedCount'),
        ],
      ),
    );
  }
}

class _HospitalResponseList extends StatelessWidget {
  const _HospitalResponseList({
    required this.listKey,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.children,
  });

  final Key listKey;
  final String emptyTitle;
  final String emptyDescription;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                emptyDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: listKey,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, int index) => children[index],
    );
  }
}

class _HospitalResponseCard extends StatelessWidget {
  const _HospitalResponseCard({required this.hospital});

  final HospitalResponse hospital;

  @override
  Widget build(BuildContext context) {
    final bool isPending = hospital.isPending;
    final Color statusColor = isPending
        ? AppColors.statusChecking
        : AppColors.statusNegative;
    final Color backgroundColor = isPending
        ? AppColors.checkingBackground
        : AppColors.negativeBackground;
    return Container(
      key: Key('hospitalResponseCard_${hospital.offerId}'),
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
              Expanded(
                child: Text(
                  hospital.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hospital.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (hospital.distanceMeters != null)
                _HospitalInfoChip(
                  icon: Icons.near_me_outlined,
                  label: hospital.distanceMeters! >= 1000
                      ? '${(hospital.distanceMeters! / 1000).toStringAsFixed(1)}km'
                      : '${hospital.distanceMeters}m',
                ),
              if (hospital.etaMinutes != null)
                _HospitalInfoChip(
                  icon: Icons.route_outlined,
                  label: '약 ${hospital.etaMinutes}분',
                ),
              _HospitalInfoChip(
                icon: Icons.schedule_rounded,
                label: _formatHospitalResponseTime(hospital.statusUpdatedAt),
              ),
            ],
          ),
          if (!isPending) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              '사유: ${hospital.reasonLabel ?? '병원 사정으로 수용이 어렵습니다.'}',
              style: const TextStyle(
                color: AppColors.statusNegative,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatHospitalResponseTime(DateTime value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _AcceptedStatusBar extends StatelessWidget {
  const _AcceptedStatusBar({required this.elapsedLabel});

  final String elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('acceptedHospitalStatusBar'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.radar_rounded,
            color: AppColors.statusInfo,
            size: 20,
          ),
          const SizedBox(width: 7),
          const Text('이송 요청 중', style: TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.textSecondary,
            size: 19,
          ),
          const SizedBox(width: 6),
          Text(
            elapsedLabel,
            key: const Key('acceptedHospitalElapsedTime'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedHospitalCard extends StatelessWidget {
  const _AcceptedHospitalCard({
    required this.hospital,
    required this.isSelecting,
    required this.onCall,
    required this.onDirections,
    required this.onSelect,
  });

  final AcceptedHospital hospital;
  final bool isSelecting;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('acceptedHospitalCard_${hospital.offerId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.positiveBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: AppColors.statusPositive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hospital.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hospital.fullAddress,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HospitalInfoChip(
                icon: Icons.near_me_outlined,
                label: hospital.distanceLabel,
              ),
              if (hospital.etaLabel != null)
                _HospitalInfoChip(
                  icon: Icons.route_outlined,
                  label: hospital.etaLabel!,
                ),
              _HospitalInfoChip(
                icon: Icons.check_circle_outline_rounded,
                label: '수락 ${_formatAcceptedTime(hospital.acceptedAt)}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(
                Icons.phone_outlined,
                color: AppColors.textSecondary,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '응급실 ${hospital.emergencyRoomPhone}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    key: Key('callHospital_${hospital.offerId}'),
                    onPressed: isSelecting ? null : onCall,
                    icon: const Icon(Icons.phone_rounded),
                    label: const Text('전화 걸기', maxLines: 1),
                  ),
                ),
              ),
              if (hospital.latitude != null &&
                  hospital.longitude != null) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      key: Key('directionsHospital_${hospital.offerId}'),
                      onPressed: isSelecting ? null : onDirections,
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('길찾기', maxLines: 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: Key('selectDestination_${hospital.offerId}'),
              onPressed: isSelecting ? null : onSelect,
              child: isSelecting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.textOnDark,
                      ),
                    )
                  : const Text('병원으로 이송', maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAcceptedTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    final String second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _ConfirmActionDialog extends StatelessWidget {
  const _ConfirmActionDialog({
    required this.dialogKey,
    required this.title,
    required this.description,
    required this.cancelLabel,
    required this.confirmLabel,
    this.destructive = false,
  });

  final Key dialogKey;
  final String title;
  final String description;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: dialogKey,
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
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                        key: const Key('cancelConfirmationButton'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.disabled,
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('confirmActionButton'),
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: destructive
                              ? AppColors.statusNegative
                              : AppColors.primary,
                          foregroundColor: AppColors.textOnDark,
                        ),
                        child: Text(confirmLabel),
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

class _HospitalInfoChip extends StatelessWidget {
  const _HospitalInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
