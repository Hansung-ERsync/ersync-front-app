import 'package:er_sync/core/theme/app_colors.dart';
import 'package:er_sync/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Material controls use the ERSync neutral and brand colors', () {
    final ThemeData theme = AppTheme.light;

    expect(theme.canvasColor, AppColors.surface);
    expect(theme.focusColor, AppColors.infoBackground);
    expect(theme.highlightColor, AppColors.infoBackground);
    expect(
      theme.switchTheme.trackColor?.resolve(const <WidgetState>{}),
      AppColors.surfaceMuted,
    );
    expect(
      theme.switchTheme.trackColor?.resolve(const <WidgetState>{
        WidgetState.selected,
      }),
      AppColors.primary,
    );
    expect(
      theme.switchTheme.thumbColor?.resolve(const <WidgetState>{
        WidgetState.selected,
      }),
      AppColors.textOnDark,
    );
  });
}
