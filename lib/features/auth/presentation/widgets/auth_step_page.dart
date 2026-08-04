import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AuthStepPage extends StatelessWidget {
  const AuthStepPage({
    super.key,
    required this.title,
    required this.step,
    required this.child,
    required this.bottom,
  });

  final String title;
  final int step;
  final Widget child;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                '$step / 2',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          LinearProgressIndicator(
            value: step / 2,
            minHeight: 3,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceMuted,
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: bottom,
      ),
    );
  }
}
