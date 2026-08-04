import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_view_model.dart';

class SignUpSuccessPage extends ConsumerWidget {
  const SignUpSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authViewModelProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          minimum: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.positiveBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.statusPositive,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '회원가입이 완료되었습니다',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${authState.registeredUsername ?? ''} 아이디로\n로그인해주세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('goToLoginButton'),
                  onPressed: () => context.goNamed('login'),
                  child: const Text('로그인하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
