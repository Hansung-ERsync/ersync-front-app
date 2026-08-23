import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/korean_mobile_phone_formatter.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/paramedic_profile_input_validator.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _callbackContactController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyProfile(ref.read(authViewModelProvider).user);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _displayNameController.dispose();
    _callbackContactController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final bool success = await ref
        .read(authViewModelProvider.notifier)
        .refreshMyProfile();
    if (!mounted) {
      return;
    }
    final AuthState authState = ref.read(authViewModelProvider);
    if (success) {
      _applyProfile(authState.user);
      return;
    }
    _handleFailure(authState, wasSaving: false);
  }

  Future<void> _saveProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool success = await ref
        .read(authViewModelProvider.notifier)
        .updateMyProfile(
          displayName: _displayNameController.text,
          callbackContact: _callbackContactController.text,
        );
    if (!mounted) {
      return;
    }
    final AuthState authState = ref.read(authViewModelProvider);
    if (!success) {
      _handleFailure(authState, wasSaving: true);
      return;
    }

    _applyProfile(authState.user);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('프로필을 저장했습니다.')));
  }

  void _applyProfile(AuthUser? user) {
    if (user == null) {
      return;
    }
    _organizationNameController.text = user.organizationName;
    _displayNameController.text = user.displayName;
    _callbackContactController.text = user.callbackContact;
  }

  void _handleFailure(AuthState authState, {required bool wasSaving}) {
    if (authState.user == null) {
      context.goNamed(
        'login',
        extra: _errorMessage(authState, wasSaving: wasSaving),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_errorMessage(authState, wasSaving: wasSaving))),
      );
  }

  String _errorMessage(AuthState state, {required bool wasSaving}) {
    final String message = switch (state.errorCode) {
      'AUTH_003' => '구급대원 계정만 이 기능을 사용할 수 있습니다.',
      'COMMON_004' => '인증 정보가 일치하지 않습니다. 다시 로그인한 뒤 운영 담당자에게 문의해주세요.',
      'USER_001' => '구급대원 프로필을 찾을 수 없습니다. 운영 담당자에게 문의해주세요.',
      'USER_005' => '필요한 연락처 동의를 확인할 수 없습니다. 운영 담당자에게 문의해주세요.',
      'NETWORK_ERROR' || 'NETWORK_TIMEOUT' when wasSaving =>
        '저장 완료 여부를 확인할 수 없습니다. 다시 저장하거나 최신 정보를 불러와 확인해주세요.',
      _ =>
        state.errorMessage ??
            (wasSaving ? '프로필을 저장하지 못했습니다.' : '프로필을 불러오지 못했습니다.'),
    };
    if (state.traceId == null || state.traceId!.isEmpty) {
      return message;
    }
    return '$message (문의 코드: ${state.traceId})';
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authViewModelProvider);
    final bool busy = authState.isProfileLoading || authState.isProfileSaving;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('내 프로필'),
        actions: <Widget>[
          IconButton(
            key: const Key('refreshProfileButton'),
            onPressed: busy ? null : _refreshProfile,
            tooltip: '최신 프로필 불러오기',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: <Widget>[
          if (authState.isProfileLoading) ...<Widget>[
            const LinearProgressIndicator(key: Key('profileLoadingIndicator')),
            const SizedBox(height: 20),
          ],
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '소속 구급대',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('profileOrganizationNameField'),
                  controller: _organizationNameController,
                  enabled: false,
                ),
                const SizedBox(height: 24),
                Text(
                  '표시 이름',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('profileDisplayNameField'),
                  controller: _displayNameController,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.name],
                  decoration: const InputDecoration(hintText: '이름 입력'),
                  validator: ParamedicProfileInputValidator.displayNameError,
                ),
                const SizedBox(height: 24),
                Text(
                  '병원 회신 연락처',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('profileCallbackContactField'),
                  controller: _callbackContactController,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  inputFormatters: const <KoreanMobilePhoneFormatter>[
                    KoreanMobilePhoneFormatter(),
                  ],
                  decoration: const InputDecoration(hintText: '010-0000-0000'),
                  validator:
                      ParamedicProfileInputValidator.callbackContactError,
                  onFieldSubmitted: busy ? null : (_) => _saveProfile(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '변경한 연락처는 저장 후 새로 생성하는 이송 요청부터 적용됩니다. 기존 이송 요청의 연락처는 바뀌지 않습니다.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('saveProfileButton'),
                    onPressed: busy ? null : _saveProfile,
                    child: authState.isProfileSaving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnDark,
                            ),
                          )
                        : const Text('저장'),
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
