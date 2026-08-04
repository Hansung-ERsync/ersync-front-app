import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum AppGuidePromptAction { openGuide, later }

class AppGuidePromptSheet extends StatelessWidget {
  const AppGuidePromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.infoBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.statusInfo,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ERSync가 처음이신가요?',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                '환자 평가부터 이송 요청까지의 입력 방법을\n1분 안에 확인할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('openAppGuideButton'),
                  onPressed: () =>
                      Navigator.of(context).pop(AppGuidePromptAction.openGuide),
                  child: const Text('사용법 확인하기'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: const Key('dismissAppGuideButton'),
                  onPressed: () =>
                      Navigator.of(context).pop(AppGuidePromptAction.later),
                  child: const Text('나중에'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
