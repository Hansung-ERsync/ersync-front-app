import 'package:er_sync/app.dart';
import 'package:er_sync/core/assets/app_assets.dart';
import 'package:er_sync/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ERSync 로그인 화면의 주요 요소를 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const ErSyncApp());

    expect(find.text('ERSync'), findsOneWidget);
    expect(find.text('응급 이송 연계'), findsOneWidget);
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('아이디 입력'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('비밀번호 입력'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('가입 코드로 회원가입'), findsOneWidget);
    expect(find.text('구급대원 전용'), findsOneWidget);

    final Image image = tester.widget<Image>(find.byType(Image));
    final AssetImage provider = image.image as AssetImage;
    expect(provider.assetName, AppAssets.shieldMark);
  });

  testWidgets('빈 로그인 폼을 제출하면 필수값 오류를 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const ErSyncApp());

    final Finder loginButton = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('아이디를 입력해주세요'), findsOneWidget);
    expect(find.text('비밀번호를 입력해주세요'), findsOneWidget);
  });

  testWidgets('비밀번호 표시 상태를 전환한다', (WidgetTester tester) async {
    await tester.pumpWidget(const ErSyncApp());

    final Finder passwordInput = find.descendant(
      of: find.byKey(const Key('passwordField')),
      matching: find.byType(EditableText),
    );
    EditableText editableText = tester.widget<EditableText>(passwordInput);
    expect(editableText.obscureText, isTrue);

    await tester.tap(find.byKey(const Key('passwordVisibilityButton')));
    await tester.pump();

    editableText = tester.widget<EditableText>(passwordInput);
    expect(editableText.obscureText, isFalse);
  });

  test('Pre-KTAS 1~5단계 색상을 제공한다', () {
    expect(AppColors.preKtasButtonByLevel.keys, <int>[1, 2, 3, 4, 5]);
    expect(AppColors.preKtasButton(1), const Color(0xFFE7000B));
    expect(AppColors.preKtasButton(5), const Color(0xFF155DFC));
    expect(() => AppColors.preKtasButton(6), throwsA(isA<RangeError>()));
  });
}
