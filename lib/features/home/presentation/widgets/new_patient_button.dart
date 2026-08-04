import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class NewPatientButton extends StatelessWidget {
  const NewPatientButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

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
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 176,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_rounded, size: 42, color: AppColors.textOnDark),
                SizedBox(height: 12),
                Text(
                  '새 환자 등록',
                  style: TextStyle(
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
