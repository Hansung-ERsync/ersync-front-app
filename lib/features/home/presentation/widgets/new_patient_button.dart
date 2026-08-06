import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class NewPatientButton extends StatelessWidget {
  const NewPatientButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '새 환자 등록',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: const Color(0x40000000),
        child: InkWell(
          key: const Key('newPatientButton'),
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onPressed,
          child: SizedBox.square(
            dimension: 176,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isLoading)
                  const SizedBox.square(
                    key: Key('newPatientLoadingIndicator'),
                    dimension: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.textOnDark,
                    ),
                  )
                else
                  const Icon(
                    Icons.add_rounded,
                    size: 42,
                    color: AppColors.textOnDark,
                  ),
                const SizedBox(height: 12),
                Text(
                  isLoading ? '환자 화면 준비 중' : '새 환자 등록',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
