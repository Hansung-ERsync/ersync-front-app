import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../transport/domain/entities/transport_session.dart';
import '../../domain/entities/accepted_hospital.dart';
import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';
import '../providers/hospital_search_view_model.dart';

class HospitalSearchPage extends ConsumerStatefulWidget {
  const HospitalSearchPage({super.key, required this.session});

  final HospitalSearchSession session;

  @override
  ConsumerState<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends ConsumerState<HospitalSearchPage> {
  late final HospitalSearchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(hospitalSearchViewModelProvider.notifier);
    Future<void>.microtask(() => _viewModel.start(widget.session));
  }

  @override
  void dispose() {
    _viewModel.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HospitalSearchViewState state = ref.watch(
      hospitalSearchViewModelProvider,
    );
    final HospitalSearchProgress progress =
        state.progress ??
        HospitalSearchProgress(
          requestId: widget.session.requestId,
          currentRadiusKm: widget.session.initialRadiusKm,
          elapsedSeconds: 0,
        );

    if (progress.acceptedHospitals.isNotEmpty) {
      return _buildAcceptedHospitalsScreen(state, progress);
    }

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
                              '${_formatMinutes(widget.session.expansionIntervalSeconds)} 미응답 시 '
                              '${widget.session.radiusStepKm}km씩 자동 확대됩니다.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _SearchRadiusCard(
                              currentRadiusKm: progress.currentRadiusKm,
                            ),
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

  Widget _buildAcceptedHospitalsScreen(
    HospitalSearchViewState state,
    HospitalSearchProgress progress,
  ) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _AcceptedStatusBar(
                radiusKm: progress.currentRadiusKm,
                elapsedLabel: _formatElapsed(progress.elapsedSeconds),
              ),
              Expanded(
                child: ListView(
                  key: const Key('acceptedHospitalList'),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  children: <Widget>[
                    Text(
                      '수락 병원 선택',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '병원이 수용 가능 상태로 응답했습니다. 실제 이송할 목적지를 선택해주세요.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...progress.acceptedHospitals.map(
                      (AcceptedHospital hospital) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _AcceptedHospitalCard(
                          hospital: hospital,
                          isSelecting: state.isSelectingDestination,
                          onCall: () => _callHospital(hospital),
                          onSelect: () => _selectDestination(hospital),
                        ),
                      ),
                    ),
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.statusNegative,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
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
            confirmLabel: '취소 계속',
            destructive: true,
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final TransportCancellationReason? reason =
        await showModalBottomSheet<TransportCancellationReason>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => const _CancellationReasonSheet(),
        );
    if (reason == null || !mounted) {
      return;
    }
    final bool cancelled = await _viewModel.cancel(reason);
    if (cancelled && mounted) {
      context.goNamed('home');
    }
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

class _SearchRadiusCard extends StatelessWidget {
  const _SearchRadiusCard({required this.currentRadiusKm});

  final int currentRadiusKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('currentSearchRadiusCard'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        border: Border.all(color: AppColors.infoBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar_rounded, color: AppColors.statusInfo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '현재 전송 범위',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${currentRadiusKm}km 이내 병원에 전송 중',
                  key: const Key('currentSearchRadiusText'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedStatusBar extends StatelessWidget {
  const _AcceptedStatusBar({
    required this.radiusKm,
    required this.elapsedLabel,
  });

  final int radiusKm;
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
          Text(
            '${radiusKm}km 전송 범위',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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
    required this.onSelect,
  });

  final AcceptedHospital hospital;
  final bool isSelecting;
  final VoidCallback onCall;
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
                      hospital.address,
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
              _HospitalInfoChip(
                icon: Icons.route_outlined,
                label: hospital.etaLabel,
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
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
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
              ),
            ],
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

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet();

  @override
  State<_CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  TransportCancellationReason? _selectedReason;

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
                  onTap: () => setState(() => _selectedReason = reason),
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: const Key('confirmTransportCancellationButton'),
              onPressed: _selectedReason == null
                  ? null
                  : () => Navigator.of(context).pop(_selectedReason),
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
