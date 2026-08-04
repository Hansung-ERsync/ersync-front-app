import 'package:flutter/material.dart';

/// ERSync에서 사용하는 원색과 의미 기반 색상 토큰입니다.
///
/// 화면에서는 임의의 [Color]를 만들기보다 이 클래스의 토큰을 사용합니다.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF101828);
  static const Color primaryPressed = Color(0xFF0C111D);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF6A7282);
  static const Color textTertiary = Color(0xFF99A1AF);
  static const Color textDisabled = Color(0xFFD1D5DC);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Surface and border
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color scrim = Color(0x99000000);

  // Transport and hospital response status
  static const Color statusPositive = Color(0xFF00A63E);
  static const Color statusChecking = Color(0xFFA65F00);
  static const Color statusNegative = Color(0xFFE7000B);
  static const Color statusInfo = Color(0xFF155DFC);
  static const Color statusUnavailable = Color(0xFF475467);
  static const Color statusRefused = Color(0xFFB42318);

  static const Color positiveBadgeBackground = Color(0xFFDCFCE7);
  static const Color positiveBackground = Color(0xFFF0FDF4);
  static const Color positiveBorder = Color(0xFFBBF7D0);
  static const Color checkingBackground = Color(0xFFFFFBEB);
  static const Color checkingBorder = Color(0xFFFDE68A);
  static const Color negativeBackground = Color(0xFFFEF2F2);
  static const Color negativeBorder = Color(0xFFFECACA);
  static const Color infoBackground = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);
  static const Color unavailableBackground = Color(0xFFF8FAFC);
  static const Color unavailableBorder = Color(0xFFD0D5DD);

  // Pre-KTAS button backgrounds
  static const Color preKtasLevel1 = Color(0xFFE7000B);
  static const Color preKtasLevel2 = Color(0xFFFF6900);
  static const Color preKtasLevel3 = Color(0xFFFDC700);
  static const Color preKtasLevel4 = Color(0xFF00A63E);
  static const Color preKtasLevel5 = Color(0xFF155DFC);

  // Pre-KTAS button foregrounds selected for readable contrast.
  static const Color onPreKtasLevel1 = Color(0xFFFFFFFF);
  static const Color onPreKtasLevel2 = Color(0xFF101828);
  static const Color onPreKtasLevel3 = Color(0xFF101828);
  static const Color onPreKtasLevel4 = Color(0xFF101828);
  static const Color onPreKtasLevel5 = Color(0xFFFFFFFF);

  static const Map<int, Color> preKtasButtonByLevel = <int, Color>{
    1: preKtasLevel1,
    2: preKtasLevel2,
    3: preKtasLevel3,
    4: preKtasLevel4,
    5: preKtasLevel5,
  };

  static const Map<int, Color> onPreKtasButtonByLevel = <int, Color>{
    1: onPreKtasLevel1,
    2: onPreKtasLevel2,
    3: onPreKtasLevel3,
    4: onPreKtasLevel4,
    5: onPreKtasLevel5,
  };

  static Color preKtasButton(int level) {
    return preKtasButtonByLevel[level] ??
        (throw RangeError.range(level, 1, 5, 'level'));
  }

  static Color onPreKtasButton(int level) {
    return onPreKtasButtonByLevel[level] ??
        (throw RangeError.range(level, 1, 5, 'level'));
  }
}
