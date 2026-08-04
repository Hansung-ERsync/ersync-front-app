import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.onSubmit,
    required this.onSignUp,
    required this.isLoading,
    this.initialUsername = '',
  });

  final Future<void> Function(String username, String password) onSubmit;
  final VoidCallback onSignUp;
  final bool isLoading;
  final String initialUsername;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      await widget.onSubmit(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w500);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('아이디', style: labelStyle),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('usernameField'),
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            autofillHints: const <String>[AutofillHints.username],
            decoration: const InputDecoration(hintText: '아이디 입력'),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return '아이디를 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          Text('비밀번호', style: labelStyle),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('passwordField'),
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const <String>[AutofillHints.password],
            obscureText: _obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: '비밀번호 입력',
              suffixIcon: IconButton(
                key: const Key('passwordVisibilityButton'),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('loginButton'),
              onPressed: widget.isLoading ? null : _submit,
              child: widget.isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnDark,
                      ),
                    )
                  : const Text('로그인'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const Key('signUpButton'),
              onPressed: widget.isLoading ? null : widget.onSignUp,
              child: const Text('가입 코드로 회원가입'),
            ),
          ),
        ],
      ),
    );
  }
}
