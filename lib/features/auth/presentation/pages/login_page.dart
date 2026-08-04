import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_view_model.dart';
import '../widgets/login_brand.dart';
import '../widgets/login_form.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    String username,
    String password,
  ) async {
    final bool success = await ref
        .read(authViewModelProvider.notifier)
        .signIn(username: username, password: password);

    if (!context.mounted) {
      return;
    }

    if (success) {
      context.goNamed('home');
      return;
    }

    final String message =
        ref.read(authViewModelProvider).errorMessage ?? '로그인에 실패했습니다.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double topPadding = constraints.maxHeight >= 720 ? 76 : 40;
            final double minimumContentHeight =
                constraints.maxHeight - topPadding - 32;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minimumContentHeight > 0
                      ? minimumContentHeight
                      : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const LoginBrand(),
                      const SizedBox(height: 64),
                      LoginForm(
                        initialUsername: authState.registeredUsername ?? '',
                        isLoading: authState.isLoading,
                        onSubmit: (String username, String password) =>
                            _signIn(context, ref, username, password),
                        onSignUp: () {
                          ref
                              .read(authViewModelProvider.notifier)
                              .startSignUp();
                          context.pushNamed('signUpCode');
                        },
                      ),
                      const Spacer(),
                      const SizedBox(height: 48),
                      Text(
                        '구급대원 전용',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
