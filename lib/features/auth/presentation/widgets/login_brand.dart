import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

class LoginBrand extends StatelessWidget {
  const LoginBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image.asset(
                AppAssets.shieldMark,
                width: 44,
                semanticLabel: 'ERSync 방패 심볼',
              ),
              const SizedBox(width: 16),
              Text(
                'ERSync',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '응급 이송 연계',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
