import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

class AppGuidePage extends StatelessWidget {
  const AppGuidePage({super.key});

  static const List<_GuideStep> _steps = <_GuideStep>[
    _GuideStep(
      number: 1,
      title: '환자 기본 정보',
      description: '환자를 특정하지 않는 범위에서 기본 상태와 발생 정보를 기록합니다.',
      assetPath: AppAssets.guideBasicInformation,
      placeholderIcon: Icons.person_search_rounded,
      actions: <String>[
        '나이는 정확·추정·확인 불가 중 하나를 선택하고, 필요한 경우 숫자를 입력합니다.',
        '성별과 발생 유형을 선택합니다. 비질병이면 손상 기전과 손상 부위를 추가합니다.',
        '증상 발생 시각을 정확·추정·확인 불가로 구분합니다. 다음을 누르면 실제 시각을 확인합니다.',
      ],
    ),
    _GuideStep(
      number: 2,
      title: '증상 및 중증도',
      description: '현재 증상과 중증도, 의식 상태를 같은 관찰 시점 기준으로 기록합니다.',
      assetPath: AppAssets.guideClassification,
      placeholderIcon: Icons.monitor_heart_rounded,
      actions: <String>[
        '주증상은 하나를 선택하고, 필요한 부증상은 여러 개 추가합니다.',
        '분류 완료라면 Pre-KTAS 1~5단계를, 긴급 전송이라면 예외 사유를 선택합니다.',
        'AVPU를 선택하고 평가 불가라면 사유를 기록합니다. 다음을 누르면 분류·관찰 시각을 확인합니다.',
      ],
    ),
    _GuideStep(
      number: 3,
      title: '활력징후',
      description: '각 활력징후를 값 또는 공식 상태로 빠짐없이 기록합니다.',
      assetPath: AppAssets.guideVitalSigns,
      placeholderIcon: Icons.monitor_heart_outlined,
      actions: <String>[
        '혈압·맥박·호흡수·체온·산소포화도마다 측정값·측정 불가·환자 거부를 선택합니다.',
        '측정값은 직접 입력하거나 −/＋로 조절하고, 혈압은 수축기와 이완기를 모두 입력합니다.',
        '측정 불가는 현장 사유를 선택하고 기타라면 직접 입력합니다. 다음을 누르면 측정 시각을 확인합니다.',
      ],
    ),
    _GuideStep(
      number: 4,
      title: '처치 및 전송 확인',
      description: '처치 기록과 전송 정보를 마지막으로 검토한 뒤 요청을 보냅니다.',
      assetPath: AppAssets.guideTreatmentReview,
      placeholderIcon: Icons.emergency_share_rounded,
      actions: <String>[
        '시행한 처치를 하나 이상 선택합니다. 이송 요청 버튼을 누르면 처치·확인 시각을 확인합니다.',
        '필요한 추가 평가를 입력합니다. 동공 반응은 입력할 경우 좌우를 모두 기록합니다.',
        '입력을 확인하고 이송 요청을 보내면 병원 응답 상태를 확인하고, 수용 가능한 병원을 목적지로 선택해 이송을 시작합니다.',
        '병원 도착 후 인계를 요청합니다. 병원이 인계 완료를 확인하면 이송이 최종 완료됩니다.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '앱 사용법',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '환자 평가'),
              Tab(text: '상태 안내'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_AssessmentGuideTab(), _StatusGuideTab()],
        ),
      ),
    );
  }
}

class _AssessmentGuideTab extends StatelessWidget {
  const _AssessmentGuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        const _QuickStartCard(),
        const SizedBox(height: 24),
        ...AppGuidePage._steps.expand(
          (_GuideStep step) => <Widget>[
            _GuideStepCard(step: step),
            const SizedBox(height: 16),
          ],
        ),
        const _SafetyNotice(),
      ],
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.bolt_rounded, color: AppColors.textOnDark, size: 22),
              SizedBox(width: 8),
              Text(
                '1분 빠른 시작',
                style: TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '환자 정보 → 증상·중증도 → 활력징후 → 처치·전송 확인',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '각 단계의 필수값이 완료되면 다음 버튼이 활성화됩니다.',
            style: TextStyle(color: Color(0xFFD0D5DD), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('appGuideStep_${step.number}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'STEP ${step.number.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.statusInfo,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                ...step.actions.indexed.map(
                  ((int, String) action) =>
                      _GuideActionItem(number: action.$1 + 1, text: action.$2),
                ),
              ],
            ),
          ),
          _GuideImage(step: step),
        ],
      ),
    );
  }
}

class _GuideActionItem extends StatelessWidget {
  const _GuideActionItem({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.infoBackground,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.statusInfo,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideImage extends StatelessWidget {
  const _GuideImage({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.asset(
        step.assetPath,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _GuideImagePlaceholder(icon: step.placeholderIcon);
        },
      ),
    );
  }
}

class _GuideImagePlaceholder extends StatelessWidget {
  const _GuideImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.infoBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.statusInfo, size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              '가이드 화면 이미지',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusGuideTab extends StatelessWidget {
  const _StatusGuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: const <Widget>[
        _StatusExplanationCard(
          title: '확인 불가',
          description: '환자 정보나 발생 시각처럼 현재 알 수 없는 정보를 기록할 때 사용합니다.',
          color: AppColors.statusUnavailable,
          backgroundColor: AppColors.unavailableBackground,
          borderColor: AppColors.unavailableBorder,
        ),
        SizedBox(height: 12),
        _StatusExplanationCard(
          title: '측정 불가',
          description: '측정을 시도할 수 없거나 측정값을 얻지 못한 경우 사유와 함께 사용합니다.',
          color: AppColors.statusChecking,
          backgroundColor: AppColors.checkingBackground,
          borderColor: AppColors.checkingBorder,
        ),
        SizedBox(height: 12),
        _StatusExplanationCard(
          title: '환자 거부',
          description: '측정이나 평가를 환자가 명시적으로 거부한 경우 사용합니다.',
          color: AppColors.statusNegative,
          backgroundColor: AppColors.negativeBackground,
          borderColor: AppColors.negativeBorder,
        ),
        SizedBox(height: 24),
        _ProblemGuideCard(),
        SizedBox(height: 16),
        _SafetyNotice(),
      ],
    );
  }
}

class _StatusExplanationCard extends StatelessWidget {
  const _StatusExplanationCard({
    required this.title,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String title;
  final String description;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemGuideCard extends StatelessWidget {
  const _ProblemGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '전송이 되지 않을 때',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12),
          _ProblemItem(number: 1, text: '필수 입력과 GPS 연결 상태를 확인합니다.'),
          _ProblemItem(number: 2, text: '네트워크 연결을 확인한 뒤 같은 요청으로 다시 전송합니다.'),
          _ProblemItem(number: 3, text: '계속 실패하면 기존 공식 연락 체계를 이용합니다.'),
        ],
      ),
    );
  }
}

class _ProblemItem extends StatelessWidget {
  const _ProblemItem({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnDark,
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.checkingBackground,
        border: Border.all(color: AppColors.checkingBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.statusChecking,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ERSync는 정보 전달을 돕는 도구입니다. 의료 판단과 공식 지휘·연락 절차를 대신하지 않습니다.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.placeholderIcon,
    required this.actions,
  });

  final int number;
  final String title;
  final String description;
  final String assetPath;
  final IconData placeholderIcon;
  final List<String> actions;
}
