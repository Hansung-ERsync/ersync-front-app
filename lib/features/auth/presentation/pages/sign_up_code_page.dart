import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/mock_auth_data_source.dart';
import '../providers/auth_view_model.dart';
import '../widgets/auth_step_page.dart';

class SignUpCodePage extends ConsumerStatefulWidget {
  const SignUpCodePage({super.key});

  @override
  ConsumerState<SignUpCodePage> createState() => _SignUpCodePageState();
}

class _SignUpCodePageState extends ConsumerState<SignUpCodePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool success = await ref
        .read(authViewModelProvider.notifier)
        .validateInvitationCode(_codeController.text);

    if (!mounted) {
      return;
    }

    if (success) {
      context.pushNamed('signUpAccount');
      return;
    }

    final String message =
        ref.read(authViewModelProvider).errorMessage ?? '가입 코드를 확인해주세요.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authViewModelProvider);

    return AuthStepPage(
      title: '가입 코드 확인',
      step: 1,
      bottom: FilledButton(
        key: const Key('invitationCodeSubmitButton'),
        onPressed: authState.isLoading ? null : _submit,
        child: authState.isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnDark,
                ),
              )
            : const Text('가입 코드 확인'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '소속 확인',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '관리자에게 전달받은 가입 코드를 입력하면\n소속 구급대와 역할을 확인합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              '가입 코드',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('invitationCodeField'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: '가입 코드 입력',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return '가입 코드를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.infoBackground,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.science_outlined,
                    color: AppColors.statusInfo,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '목 데이터 테스트 코드',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.statusInfo,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const SelectableText(
                          MockAuthDataSource.mockInvitationCode,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('fillMockInvitationCodeButton'),
                    onPressed: () {
                      _codeController.text =
                          MockAuthDataSource.mockInvitationCode;
                    },
                    child: const Text('입력'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
