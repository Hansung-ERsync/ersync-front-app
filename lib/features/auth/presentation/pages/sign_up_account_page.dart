import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/korean_mobile_phone_formatter.dart';
import '../../domain/entities/invitation_info.dart';
import '../providers/auth_view_model.dart';
import '../widgets/auth_step_page.dart';

class SignUpAccountPage extends ConsumerStatefulWidget {
  const SignUpAccountPage({super.key});

  @override
  ConsumerState<SignUpAccountPage> createState() => _SignUpAccountPageState();
}

class _SignUpAccountPageState extends ConsumerState<SignUpAccountPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _callbackContactController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _callbackContactController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool consented = await _showPrivacyConsentSheet();
    if (!consented || !mounted) {
      return;
    }

    final bool success = await ref
        .read(authViewModelProvider.notifier)
        .signUp(
          displayName: _displayNameController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          callbackContact: _callbackContactController.text,
          collectionUseConsent: true,
          hospitalProvisionConsent: true,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      context.goNamed('signUpSuccess');
      return;
    }

    final String message =
        ref.read(authViewModelProvider).errorMessage ?? '회원가입에 실패했습니다.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showPrivacyConsentSheet() async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => const _PrivacyConsentSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authViewModelProvider);
    final InvitationInfo? invitation = authState.invitation;

    if (invitation == null) {
      return AuthStepPage(
        title: '계정 정보 입력',
        step: 2,
        bottom: FilledButton(
          onPressed: () => context.goNamed('signUpCode'),
          child: const Text('가입 코드 입력으로 돌아가기'),
        ),
        child: const Center(child: Text('확인된 가입 코드가 없습니다.')),
      );
    }

    return AuthStepPage(
      title: '계정 정보 입력',
      step: 2,
      bottom: FilledButton(
        key: const Key('signUpSubmitButton'),
        onPressed: authState.isLoading ? null : _submit,
        child: authState.isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnDark,
                ),
              )
            : const Text('회원가입'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '소속이 확인되었습니다',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.positiveBackground,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.statusPositive,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          invitation.organizationName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          invitation.role.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.statusPositive),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _FieldLabel(text: '이름'),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signUpDisplayNameField'),
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              decoration: const InputDecoration(hintText: '이름 입력'),
              validator: (String? value) {
                final String displayName = value?.trim() ?? '';
                if (displayName.isEmpty) {
                  return '이름을 입력해주세요';
                }
                if (displayName.length < 2) {
                  return '이름은 2자 이상 입력해주세요';
                }
                if (displayName.length > 50) {
                  return '이름은 50자 이하로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: '병원 회신용 전화번호'),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signUpCallbackContactField'),
              controller: _callbackContactController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              inputFormatters: const <KoreanMobilePhoneFormatter>[
                KoreanMobilePhoneFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: '010-0000-0000',
                helperText: '이송 요청을 받은 병원이 구급대원에게 회신할 번호',
              ),
              validator: (String? value) {
                final String contact = value?.trim() ?? '';
                if (contact.isEmpty) {
                  return '병원 회신용 전화번호를 입력해주세요';
                }
                if (!RegExp(r'^010-\d{4}-\d{4}$').hasMatch(contact)) {
                  return '010-0000-0000 형식으로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: '아이디'),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signUpUsernameField'),
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '아이디 입력'),
              validator: (String? value) {
                final String username = value?.trim() ?? '';
                if (username.isEmpty) {
                  return '아이디를 입력해주세요';
                }
                if (!RegExp(r'^[a-z0-9]{4,30}$').hasMatch(username)) {
                  return '아이디는 영문 소문자와 숫자 4~30자로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: '비밀번호'),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signUpPasswordField'),
              controller: _passwordController,
              textInputAction: TextInputAction.next,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: '비밀번호 입력',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return '비밀번호를 입력해주세요';
                }
                if (value.length < 8) {
                  return '비밀번호는 8자 이상 입력해주세요';
                }
                if (value.length > 64) {
                  return '비밀번호는 64자 이하로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: '비밀번호 확인'),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signUpPasswordConfirmField'),
              controller: _passwordConfirmController,
              textInputAction: TextInputAction.done,
              obscureText: _obscurePasswordConfirm,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: '비밀번호 다시 입력',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
                    );
                  },
                  icon: Icon(
                    _obscurePasswordConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return '비밀번호를 다시 입력해주세요';
                }
                if (value != _passwordController.text) {
                  return '비밀번호가 일치하지 않습니다';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyConsentSheet extends StatefulWidget {
  const _PrivacyConsentSheet();

  @override
  State<_PrivacyConsentSheet> createState() => _PrivacyConsentSheetState();
}

class _PrivacyConsentSheetState extends State<_PrivacyConsentSheet> {
  bool _collectionUseConsent = false;
  bool _hospitalProvisionConsent = false;

  bool get _allConsented => _collectionUseConsent && _hospitalProvisionConsent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('privacyConsentSheet'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '개인정보 동의',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '병원 회신용 전화번호의 사용 범위를 확인해주세요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: <Widget>[
                  CheckboxListTile(
                    key: const Key('consentAllCheckbox'),
                    value: _allConsented,
                    onChanged: (bool? value) {
                      setState(() {
                        final bool checked = value ?? false;
                        _collectionUseConsent = checked;
                        _hospitalProvisionConsent = checked;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '필수 항목 전체 동의',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    key: const Key('collectionUseConsentCheckbox'),
                    value: _collectionUseConsent,
                    onChanged: (bool? value) {
                      setState(() => _collectionUseConsent = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '[필수] 전화번호 수집·이용 동의',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('병원 회신 연락처 등록 및 이송 요청 운영 목적으로 이용합니다.'),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    key: const Key('hospitalProvisionConsentCheckbox'),
                    value: _hospitalProvisionConsent,
                    onChanged: (bool? value) {
                      setState(
                        () => _hospitalProvisionConsent = value ?? false,
                      );
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '[필수] 요청 수신 병원 제공 동의',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('이송 요청을 실제로 받은 권한 있는 병원에만 제공합니다.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '개발·테스트 환경에서는 실제 개인번호를 사용하지 않습니다.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('consentAndSignUpButton'),
                onPressed: _allConsented
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('동의하고 회원가입'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
