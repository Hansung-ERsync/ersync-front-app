import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/login_brand.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _showApiPendingMessage(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('로그인 API 연동 전입니다.')));
  }

  void _showSignUpPendingMessage(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('가입 코드 회원가입 화면 구현 전입니다.')),
      );
  }

  @override
  Widget build(BuildContext context) {
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
                        onSubmit: () => _showApiPendingMessage(context),
                        onSignUp: () => _showSignUpPendingMessage(context),
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
