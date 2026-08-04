import 'package:er_sync/app.dart';
import 'package:er_sync/core/assets/app_assets.dart';
import 'package:er_sync/core/theme/app_colors.dart';
import 'package:er_sync/features/auth/data/datasources/mock_auth_data_source.dart';
import 'package:er_sync/features/auth/domain/entities/auth_user.dart';
import 'package:er_sync/features/auth/domain/entities/invitation_info.dart';
import 'package:er_sync/features/auth/domain/entities/privacy_consent_record.dart';
import 'package:er_sync/features/auth/presentation/providers/auth_view_model.dart';
import 'package:er_sync/features/home/presentation/pages/home_page.dart';
import 'package:er_sync/features/hospital_search/data/datasources/mock_hospital_search_data_source.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_session.dart';
import 'package:er_sync/features/hospital_search/presentation/pages/hospital_search_page.dart';
import 'package:er_sync/features/patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import 'package:er_sync/features/patient_assessment/presentation/widgets/assessment_section.dart';
import 'package:er_sync/features/settings/domain/repositories/app_guide_repository.dart';
import 'package:er_sync/features/settings/presentation/providers/app_guide_provider.dart';
import 'package:er_sync/features/transport/domain/entities/patient_transport_summary.dart';
import 'package:er_sync/features/transport/domain/entities/transport_session.dart';
import 'package:er_sync/features/transport/presentation/pages/transport_in_progress_page.dart';
import 'package:er_sync/features/transport/presentation/providers/transport_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appGuideRepositoryProvider.overrideWithValue(
            _InMemoryAppGuideRepository(),
          ),
        ],
        child: const ErSyncApp(),
      ),
    );
  }

  Future<void> dismissInitialGuide(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final Finder dismissButton = find.byKey(const Key('dismissAppGuideButton'));
    if (dismissButton.evaluate().isNotEmpty) {
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAssessmentKey(WidgetTester tester, String key) async {
    final Finder target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> confirmTimeSheet(
    WidgetTester tester,
    String buttonKey, {
    bool settle = true,
  }) async {
    final Finder confirmButton = find.byKey(Key(buttonKey));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> completeBasicStep(WidgetTester tester) async {
    await tapAssessmentKey(tester, 'ageStatus_UNKNOWN');
    await tapAssessmentKey(tester, 'patientSex_MALE');
    await tapAssessmentKey(tester, 'occurrenceType_DISEASE');
    await tapAssessmentKey(tester, 'onsetTimeStatus_UNKNOWN');
  }

  Future<void> completeClassificationStep(WidgetTester tester) async {
    await tapAssessmentKey(tester, 'primarySymptom_DYSPNEA');
    await tapAssessmentKey(tester, 'classificationStatus_COMPLETED');
    await tapAssessmentKey(tester, 'preKtasLevel2');
    await tapAssessmentKey(tester, 'avpu_A');
  }

  Future<void> completeVitalsAsRefused(WidgetTester tester) async {
    for (final String type in <String>[
      'bloodPressure',
      'pulse',
      'respiratoryRate',
      'temperature',
      'oxygenSaturation',
    ]) {
      await tapAssessmentKey(tester, 'vitalState_${type}_PATIENT_REFUSED');
    }
  }

  testWidgets('ERSync 로그인 화면의 주요 요소를 표시한다', (WidgetTester tester) async {
    await pumpApp(tester);

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
    await pumpApp(tester);

    final Finder loginButton = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('아이디를 입력해주세요'), findsOneWidget);
    expect(find.text('비밀번호를 입력해주세요'), findsOneWidget);
  });

  testWidgets('비밀번호 표시 상태를 전환한다', (WidgetTester tester) async {
    await pumpApp(tester);

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

  testWidgets('목 계정으로 로그인하면 구급대원 홈을 표시한다', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      MockAuthDataSource.mockUsername,
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      MockAuthDataSource.mockPassword,
    );
    await tester.ensureVisible(find.byKey(const Key('loginButton')));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('ERSync가 처음이신가요?'), findsOneWidget);
    expect(find.byKey(const Key('openAppGuideButton')), findsOneWidget);
    expect(find.byKey(const Key('dismissAppGuideButton')), findsOneWidget);
    expect(find.text('강동소방서 3구급대'), findsOneWidget);
    expect(find.text('김민준 대원'), findsOneWidget);
    expect(find.text('새 환자 등록'), findsOneWidget);
    expect(find.text('최근 이송'), findsOneWidget);
    expect(find.text('인계 완료'), findsNWidgets(3));
  });

  testWidgets('가입 코드로 새 구급대원 계정을 생성한다', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.byKey(const Key('signUpButton')));
    await tester.tap(find.byKey(const Key('signUpButton')));
    await tester.pumpAndSettle();

    expect(find.text('가입 코드 확인'), findsWidgets);
    await tester.tap(find.byKey(const Key('fillMockInvitationCodeButton')));
    await tester.tap(find.byKey(const Key('invitationCodeSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('소속이 확인되었습니다'), findsOneWidget);
    expect(find.text('강동소방서 3구급대'), findsOneWidget);
    expect(find.text('구급대원'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('signUpDisplayNameField')),
      '박새별',
    );
    await tester.enterText(
      find.byKey(const Key('signUpCallbackContactField')),
      '01011112222',
    );
    final EditableText callbackContactInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('signUpCallbackContactField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(callbackContactInput.controller.text, '010-1111-2222');
    await tester.enterText(
      find.byKey(const Key('signUpUsernameField')),
      'newparamedic',
    );
    await tester.enterText(
      find.byKey(const Key('signUpPasswordField')),
      'newpass1234',
    );
    await tester.enterText(
      find.byKey(const Key('signUpPasswordConfirmField')),
      'newpass1234',
    );
    await tester.tap(find.byKey(const Key('signUpSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacyConsentSheet')), findsOneWidget);
    expect(find.text('개인정보 동의'), findsOneWidget);
    final Finder consentAll = find.byKey(const Key('consentAllCheckbox'));
    await tester.ensureVisible(consentAll);
    await tester.tap(consentAll);
    await tester.pump();
    final Finder consentAndSignUp = find.byKey(
      const Key('consentAndSignUpButton'),
    );
    await tester.ensureVisible(consentAndSignUp);
    await tester.tap(consentAndSignUp);
    await tester.pumpAndSettle();

    expect(find.text('회원가입이 완료되었습니다'), findsOneWidget);
    expect(find.textContaining('newparamedic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goToLoginButton')));
    await tester.pumpAndSettle();

    final EditableText usernameInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('usernameField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(usernameInput.controller.text, 'newparamedic');

    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'newpass1234',
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await dismissInitialGuide(tester);

    expect(find.text('박새별 대원'), findsOneWidget);

    await tester.tap(find.byKey(const Key('newPatientButton')));
    await tester.pumpAndSettle();
    await completeBasicStep(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    await completeClassificationStep(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    await confirmTimeSheet(tester, 'confirmAssessedAtButton');
    await completeVitalsAsRefused(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmMeasuredAtButton')));
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('처치 및 전송 확인')),
    );
    expect(
      container
          .read(patientAssessmentViewModelProvider)
          .requireValue
          .draft
          .callbackContact,
      '010-1111-2222',
    );
    expect(find.text('010-1111-2222'), findsNothing);
  });

  testWidgets('환자 평가 4단계에서 목 이송 요청을 생성한다', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      MockAuthDataSource.mockUsername,
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      MockAuthDataSource.mockPassword,
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await dismissInitialGuide(tester);

    await tester.tap(find.byKey(const Key('newPatientButton')));
    await tester.pumpAndSettle();

    expect(find.text('환자 기본 정보'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('GPS 연결됨'), findsOneWidget);
    expect(find.text('서울 강동구 천호대로 892'), findsOneWidget);
    final Size nextButtonSize = tester.getSize(
      find.byKey(const Key('assessmentNextButton')),
    );
    expect(nextButtonSize.width, greaterThan(300));
    expect(nextButtonSize.height, 56);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('assessmentNextButton')))
          .onPressed,
      isNull,
    );

    await completeBasicStep(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('증상 및 중증도'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.byKey(const Key('preKtasLevel2')), findsNothing);

    await completeClassificationStep(tester);
    expect(find.byKey(const Key('preKtasLevel2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assessmentTimeSheet')), findsOneWidget);
    await confirmTimeSheet(tester, 'confirmAssessedAtButton');
    expect(find.text('활력징후 입력'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('산소포화도'), findsOneWidget);

    await completeVitalsAsRefused(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('measurementTimeSheet')), findsOneWidget);
    expect(find.text('측정 시간을 확인해주세요'), findsOneWidget);
    await tester.tap(find.text('10분 전'));
    await tester.pump();
    final Finder confirmMeasuredAt = find.byKey(
      const Key('confirmMeasuredAtButton'),
    );
    await tester.ensureVisible(confirmMeasuredAt);
    await tester.tap(confirmMeasuredAt);
    await tester.pumpAndSettle();
    expect(find.text('처치 및 전송 확인'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('전송 정보 확인'), findsNothing);
    expect(find.text('010-0000-0000'), findsNothing);
    expect(find.text('ERSYNC_MVP_1.0'), findsNothing);

    await tapAssessmentKey(tester, 'glucoseToggle');
    final EditableText glucoseInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('glucoseInput')),
        matching: find.byType(EditableText),
      ),
    );
    expect(glucoseInput.controller.text, '85');

    await tapAssessmentKey(tester, 'treatment_NONE');
    await tester.tap(find.byKey(const Key('submitTransferRequestButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('treatmentTimeSheet')), findsOneWidget);
    await confirmTimeSheet(tester, 'confirmPerformedAtButton', settle: false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('요청 전송 중'), findsOneWidget);
    expect(find.text('1분 미응답 시 10km씩 자동 확대됩니다.'), findsOneWidget);
    expect(find.text('10km 이내 병원에 전송 중'), findsOneWidget);
    expect(find.text('한양대학교병원 응답 대기 중'), findsNothing);
    expect(find.textContaining('KTAS'), findsNothing);
    expect(find.textContaining('수락됨'), findsNothing);
    expect(find.textContaining('이송 진행'), findsNothing);
    expect(find.textContaining('확대 알림 보기'), findsNothing);

    final FilledButton cancelRequestButton = tester.widget<FilledButton>(
      find.byKey(const Key('cancelTransportRequestButton')),
    );
    expect(
      cancelRequestButton.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppColors.statusNegative,
    );
    expect(
      cancelRequestButton.style?.foregroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppColors.textOnDark,
    );

    await tester.tap(find.byKey(const Key('cancelTransportRequestButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const Key('confirmRequestCancellationDialog')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('confirmRequestCancellationDialog')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('confirmActionButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('transportCancellationSheet')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirmTransportCancellationButton')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('cancellationReason_PATIENT_REFUSED_TRANSPORT')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('confirmTransportCancellationButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('새 환자 등록'), findsOneWidget);
  });

  testWidgets('나이와 활력징후를 직접 입력하고 혈압 측정 상태를 다시 전환한다', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      MockAuthDataSource.mockUsername,
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      MockAuthDataSource.mockPassword,
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await dismissInitialGuide(tester);
    await tester.tap(find.byKey(const Key('newPatientButton')));
    await tester.pumpAndSettle();

    await tapAssessmentKey(tester, 'ageStatus_EXACT');
    await tester.enterText(find.byKey(const Key('patientAgeInput')), '72');
    await tester.pump();
    final EditableText ageInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('patientAgeInput')),
        matching: find.byType(EditableText),
      ),
    );
    expect(ageInput.controller.text, '72');

    await tapAssessmentKey(tester, 'patientSex_MALE');
    await tapAssessmentKey(tester, 'occurrenceType_DISEASE');
    await tapAssessmentKey(tester, 'onsetTimeStatus_ESTIMATED');
    expect(find.text('10분 전'), findsNothing);

    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onsetTimeSheet')), findsOneWidget);
    expect(find.text('증상 발생 시각을 선택해주세요'), findsOneWidget);
    expect(find.text('5분 전'), findsOneWidget);
    expect(find.text('10분 전'), findsOneWidget);
    expect(find.text('30분 전'), findsOneWidget);
    expect(find.text('1시간 전'), findsNothing);
    await tester.tap(find.byKey(const Key('directClinicalTimeButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    final DateTime directInputNow = DateTime.now();
    final DateTime futureTime = directInputNow.add(const Duration(minutes: 1));
    final bool futureIsToday = futureTime.day == directInputNow.day;
    final int initialPeriodIndex = directInputNow.hour >= 12 ? 1 : 0;
    final int futurePeriodIndex = futureTime.hour >= 12 ? 1 : 0;
    if (futureIsToday) {
      if (futurePeriodIndex != initialPeriodIndex) {
        await tester.drag(
          find.byKey(const Key('clinicalTimePeriodPicker')),
          const Offset(0, -60),
        );
        await tester.pumpAndSettle();
      }
      final int futureHour12 = futureTime.hour % 12 == 0
          ? 12
          : futureTime.hour % 12;
      await tester.enterText(
        find.byKey(const Key('clinicalTimeHourInput')),
        '$futureHour12',
      );
      await tester.enterText(
        find.byKey(const Key('clinicalTimeMinuteInput')),
        '${futureTime.minute}',
      );
      await confirmTimeSheet(tester, 'confirmOnsetAtButton');
      expect(find.byKey(const Key('onsetTimeSheet')), findsOneWidget);
      expect(find.text('현재 시간 이후는 선택할 수 없습니다.'), findsOneWidget);

      if (futurePeriodIndex != initialPeriodIndex) {
        await tester.drag(
          find.byKey(const Key('clinicalTimePeriodPicker')),
          const Offset(0, 60),
        );
        await tester.pumpAndSettle();
      }
    }

    final int currentHour12 = directInputNow.hour % 12 == 0
        ? 12
        : directInputNow.hour % 12;
    await tester.enterText(
      find.byKey(const Key('clinicalTimeHourInput')),
      '$currentHour12',
    );
    await tester.enterText(
      find.byKey(const Key('clinicalTimeMinuteInput')),
      '${directInputNow.minute}',
    );
    await confirmTimeSheet(tester, 'confirmOnsetAtButton');
    await completeClassificationStep(tester);
    await tester.tap(find.byKey(const Key('assessmentNextButton')));
    await tester.pumpAndSettle();
    await confirmTimeSheet(tester, 'confirmAssessedAtButton');

    for (final MapEntry<String, String> reference in const <String, String>{
      'pulse': '80',
      'respiratoryRate': '15',
      'temperature': '37.0',
      'oxygenSaturation': '98',
    }.entries) {
      final String type = reference.key;
      await tapAssessmentKey(tester, 'vitalState_${type}_VALUE');
      final EditableText referenceInput = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key('vitalInput_$type')),
          matching: find.byType(EditableText),
        ),
      );
      expect(referenceInput.controller.text, reference.value);
      await tapAssessmentKey(tester, 'vitalState_${type}_PATIENT_REFUSED');
    }

    final Finder unavailable = find.byKey(
      const Key('vitalState_bloodPressure_MEASUREMENT_UNAVAILABLE'),
    );
    await tester.ensureVisible(unavailable);
    await tester.tap(unavailable);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('vitalUnavailableReason_bloodPressure')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('systolicBloodPressureInput')), findsNothing);
    final FilledButton disabledNext = tester.widget<FilledButton>(
      find.byKey(const Key('assessmentNextButton')),
    );
    expect(disabledNext.onPressed, isNull);

    await tapAssessmentKey(tester, 'vitalUnavailableReason_bloodPressure');
    expect(
      find.byKey(const Key('vitalUnavailableReasonSheet')),
      findsOneWidget,
    );
    await tapAssessmentKey(tester, 'unavailableReasonOption_other');
    expect(
      find.byKey(const Key('vitalUnavailableDetail_bloodPressure')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('vitalUnavailableDetail_bloodPressure')),
      '커프 적용이 어려운 특이 현장 상황',
    );
    await tester.pumpAndSettle();

    await tapAssessmentKey(tester, 'vitalState_bloodPressure_VALUE');
    expect(find.byKey(const Key('systolicBloodPressureInput')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('systolicBloodPressureInput'))).width,
      greaterThan(120),
    );
    final EditableText referenceSystolic = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('systolicBloodPressureInput')),
        matching: find.byType(EditableText),
      ),
    );
    final EditableText referenceDiastolic = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('diastolicBloodPressureInput')),
        matching: find.byType(EditableText),
      ),
    );
    expect(referenceSystolic.controller.text, '105');
    expect(referenceDiastolic.controller.text, '70');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('assessmentNextButton')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const Key('systolicBloodPressureInput')),
      '135',
    );
    await tester.enterText(
      find.byKey(const Key('diastolicBloodPressureInput')),
      '85',
    );
    await tester.pumpAndSettle();
    final EditableText systolicInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('systolicBloodPressureInput')),
        matching: find.byType(EditableText),
      ),
    );
    expect(systolicInput.controller.text, '135');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('assessmentNextButton')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('필수 입력을 완료하기 전에는 다음 버튼을 비활성화한다', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      MockAuthDataSource.mockUsername,
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      MockAuthDataSource.mockPassword,
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await dismissInitialGuide(tester);
    await tester.tap(find.byKey(const Key('newPatientButton')));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('환자 기본 정보')),
    );
    final initialDraft = container
        .read(patientAssessmentViewModelProvider)
        .requireValue
        .draft;
    expect(initialDraft.ageStatus, isNull);
    expect(initialDraft.sex, isNull);
    expect(initialDraft.occurrenceType, isNull);
    expect(initialDraft.onsetTimeStatus, isNull);
    expect(initialDraft.classificationStatus, isNull);
    expect(initialDraft.vitals, isEmpty);
    expect(initialDraft.treatments, isEmpty);

    await tapAssessmentKey(tester, 'ageStatus_UNKNOWN');
    await tapAssessmentKey(tester, 'patientSex_MALE');
    await tapAssessmentKey(tester, 'onsetTimeStatus_UNKNOWN');

    final Finder nonDisease = find.byKey(
      const Key('occurrenceType_NON_DISEASE'),
    );
    await tester.ensureVisible(nonDisease);
    await tester.tap(nonDisease);
    await tester.pumpAndSettle();

    final Finder nextButton = find.byKey(const Key('assessmentNextButton'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    expect(find.text('필수 항목을 모두 입력하면 다음으로 이동할 수 있습니다.'), findsOneWidget);

    final Finder mechanism = find.byKey(const Key('injuryMechanism_TRAFFIC'));
    await tester.ensureVisible(mechanism);
    await tester.tap(mechanism);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    final Finder injurySite = find.byKey(const Key('injurySite_HEAD_FACE'));
    await tester.ensureVisible(injurySite);
    await tester.tap(injurySite);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('작은 휴대폰 화면에서도 요청 전송 상태와 취소 버튼을 표시한다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HospitalSearchPage(
            session: HospitalSearchSession(
              requestId: 'REQ-SMALL-SCREEN',
              startedAt: DateTime.now(),
              initialRadiusKm: 10,
              radiusStepKm: 10,
              expansionIntervalSeconds: 60,
              maximumRadiusKm: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('요청 전송 중'), findsOneWidget);
    expect(find.text('10km 이내 병원에 전송 중'), findsOneWidget);
    expect(find.byKey(const Key('hospitalSearchRadar')), findsOneWidget);
    expect(
      find.byKey(const Key('cancelTransportRequestButton')),
      findsOneWidget,
    );
  });

  testWidgets('병원 수락 후 목적지를 선택하고 이송 중 활력징후를 수정한다', (WidgetTester tester) async {
    final HospitalSearchSession searchSession = HospitalSearchSession(
      requestId: 'REQ-ACCEPTED-FLOW',
      startedAt: DateTime.now().subtract(const Duration(seconds: 6)),
      initialRadiusKm: 10,
      radiusStepKm: 10,
      expansionIntervalSeconds: 60,
      maximumRadiusKm: 100,
      patientSummary: PatientTransportSummary(
        ageLabel: '72세',
        sexLabel: '남성',
        primarySymptomLabel: '호흡곤란',
        preKtasLabel: 'Pre-KTAS 2',
        avpuLabel: 'A',
        systolic: 120,
        diastolic: 80,
        respiratoryRate: 16,
        temperature: 36.5,
        oxygenSaturation: 98,
        vitalsMeasuredAt: DateTime.now().subtract(const Duration(minutes: 5)),
        pulseStateLabel: '환자 거부',
      ),
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/search',
      routes: <RouteBase>[
        GoRoute(
          path: '/search',
          builder: (_, _) => HospitalSearchPage(session: searchSession),
        ),
        GoRoute(
          path: '/transport/:requestId',
          name: 'transportInProgress',
          builder: (_, GoRouterState state) => TransportInProgressPage(
            session: state.extra! as TransportSession,
          ),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, _) => const HomePage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    final _InMemoryAppGuideRepository guideRepository =
        _InMemoryAppGuideRepository();
    await guideRepository.markGuideSeen(MockAuthDataSource.mockUsername);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_AuthenticatedAuthViewModel.new),
          appGuideRepositoryProvider.overrideWithValue(guideRepository),
        ],
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('수락 병원 선택'), findsOneWidget);
    expect(find.byKey(const Key('acceptedHospitalStatusBar')), findsOneWidget);
    expect(find.byKey(const Key('acceptedHospitalList')), findsOneWidget);
    expect(
      find.byKey(const Key('acceptedHospitalBottomAction')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('acceptedHospitalList')),
        matching: find.byKey(const Key('cancelAcceptedTransportButton')),
      ),
      findsNothing,
    );
    expect(find.text('10km 전송 범위'), findsOneWidget);
    expect(find.text('한양대학교병원'), findsOneWidget);
    expect(find.text('8.4km'), findsOneWidget);
    expect(find.text('예상 18분'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^수락 [0-9]{2}:[0-9]{2}:[0-9]{2}$')),
      findsOneWidget,
    );
    expect(find.text('한양대학교병원이 수용을 확정했습니다'), findsNothing);
    expect(find.text('환자 정보 요약'), findsNothing);
    expect(find.text('인계 완료'), findsNothing);
    expect(find.text('경로 안내 열기'), findsNothing);
    expect(
      find.byKey(const Key('callHospital_OFFER-MOCK-HANYANG')),
      findsOneWidget,
    );
    final Size callButtonSize = tester.getSize(
      find.byKey(const Key('callHospital_OFFER-MOCK-HANYANG')),
    );
    final Size destinationButtonSize = tester.getSize(
      find.byKey(const Key('selectDestination_OFFER-MOCK-HANYANG')),
    );
    expect(callButtonSize.height, 56);
    expect(destinationButtonSize.height, 56);
    expect(callButtonSize.width, destinationButtonSize.width);
    expect(find.text('병원으로 이송'), findsOneWidget);
    expect(find.text('이 병원으로 이송'), findsNothing);
    final FilledButton acceptedCancelButton = tester.widget<FilledButton>(
      find.byKey(const Key('cancelAcceptedTransportButton')),
    );
    expect(
      acceptedCancelButton.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppColors.statusNegative,
    );
    final Size acceptedCancelButtonSize = tester.getSize(
      find.byKey(const Key('cancelAcceptedTransportButton')),
    );
    expect(acceptedCancelButtonSize.width, greaterThan(300));
    expect(acceptedCancelButtonSize.height, 56);

    await tester.tap(
      find.byKey(const Key('selectDestination_OFFER-MOCK-HANYANG')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('confirmDestinationDialog')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('confirmDestinationDialog')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('confirmActionButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('이송 진행 중'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
    expect(find.byKey(const Key('destinationHospitalCard')), findsOneWidget);
    expect(
      find.byKey(const Key('callDestinationHospitalButton')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('inTransitPatientSummary')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('inTransitPatientSummary'))).height,
      lessThan(520),
    );
    expect(find.text('120/80 mmHg'), findsOneWidget);
    for (final String rowKey in <String>[
      'age',
      'sex',
      'symptom',
      'preKtas',
      'avpu',
      'bloodPressure',
      'pulse',
      'respiratoryRate',
      'temperature',
      'oxygenSaturation',
    ]) {
      expect(find.byKey(Key('patientSummaryRow_$rowKey')), findsOneWidget);
    }
    expect(find.text('2단계'), findsOneWidget);
    expect(find.text('A · 명료'), findsOneWidget);
    expect(find.text('환자 거부'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('patientSummaryValue_pulse')),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.byKey(const Key('addInTransitVitalsButton')), findsOneWidget);
    expect(find.text('활력징후 수정'), findsOneWidget);
    expect(find.text('활력징후 추가'), findsNothing);
    expect(find.text('인계 완료'), findsNothing);
    expect(find.text('경로 안내 열기'), findsNothing);

    await tester.tap(find.byKey(const Key('addInTransitVitalsButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(
      find.byKey(const Key('inTransitSystolicInput')),
      '140',
    );
    await tester.enterText(
      find.byKey(const Key('inTransitDiastolicInput')),
      '90',
    );
    tester.testTextInput.hide();
    await tester.pump();
    for (int index = 0; index < 4; index++) {
      await tester.drag(
        find.byKey(const Key('inTransitVitalUpdateList')),
        const Offset(0, -400),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('continueInTransitVitalTimeButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('inTransitVitalTimeSheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmInTransitVitalTimeButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('140/90 mmHg'), findsOneWidget);

    expect(find.byKey(const Key('inTransitBottomAction')), findsOneWidget);
    expect(find.byKey(const Key('requestHandoffButton')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byKey(const Key('requestHandoffButton')),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('requestHandoffButton')));
    await tester.pump();
    expect(
      find.byKey(const Key('confirmHandoffRequestDialog')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('confirmHandoffRequestDialog')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('confirmHandoffRequestButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('새 환자 등록'), findsOneWidget);
    expect(find.text('인계 대기 중'), findsOneWidget);
    expect(find.byKey(const Key('handoffStatus_requested')), findsOneWidget);
    final Finder currentTransport = find.byKey(
      Key('recentTransport_${searchSession.requestId}'),
    );
    Container statusBadge = tester.widget<Container>(
      find.descendant(
        of: currentTransport,
        matching: find.byKey(const Key('handoffStatus_requested')),
      ),
    );
    expect(
      (statusBadge.decoration! as BoxDecoration).color,
      AppColors.checkingBackground,
    );

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    final Future<void> hospitalConfirmation = container
        .read(mockTransportDataSourceProvider)
        .confirmHandoffByHospital(searchSession.requestId);
    await tester.pump(const Duration(milliseconds: 200));
    await hospitalConfirmation;
    await tester.pump();

    expect(find.text('인계 대기 중'), findsNothing);
    expect(find.byKey(const Key('handoffStatus_requested')), findsNothing);
    expect(find.text('인계 완료'), findsNWidgets(4));
    statusBadge = tester.widget<Container>(
      find.descendant(
        of: currentTransport,
        matching: find.byKey(const Key('handoffStatus_completed')),
      ),
    );
    expect(
      (statusBadge.decoration! as BoxDecoration).color,
      AppColors.positiveBadgeBackground,
    );
  });

  testWidgets('최초 로그인 안내에서 단계별 앱 사용법을 연다', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      MockAuthDataSource.mockUsername,
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      MockAuthDataSource.mockPassword,
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('ERSync가 처음이신가요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('openAppGuideButton')));
    await tester.pumpAndSettle();

    expect(find.text('앱 사용법'), findsOneWidget);
    expect(find.text('1분 빠른 시작'), findsOneWidget);
    expect(find.text('환자 평가'), findsOneWidget);
    expect(find.text('상태 안내'), findsOneWidget);
    expect(find.text('STEP 01'), findsOneWidget);
    expect(find.text('환자 기본 정보'), findsOneWidget);
  });

  testWidgets('나중에 선택한 안내는 반복하지 않고 설정에서 다시 연다', (WidgetTester tester) async {
    await pumpApp(tester);

    Future<void> signIn() async {
      await tester.enterText(
        find.byKey(const Key('usernameField')),
        MockAuthDataSource.mockUsername,
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        MockAuthDataSource.mockPassword,
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();
    }

    await signIn();
    await tester.tap(find.byKey(const Key('dismissAppGuideButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();

    await signIn();
    expect(find.byKey(const Key('dismissAppGuideButton')), findsNothing);

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appGuideSettingsTile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('appGuideSettingsTile')));
    await tester.pumpAndSettle();

    expect(find.text('앱 사용법'), findsOneWidget);
    expect(find.text('1분 빠른 시작'), findsOneWidget);
  });

  test('Pre-KTAS 1~5단계 색상을 제공한다', () {
    expect(AppColors.preKtasButtonByLevel.keys, <int>[1, 2, 3, 4, 5]);
    expect(AppColors.preKtasButton(1), const Color(0xFFE7000B));
    expect(AppColors.preKtasButton(5), const Color(0xFF155DFC));
    expect(AppColors.statusUnavailable, const Color(0xFF475467));
    expect(() => AppColors.preKtasButton(6), throwsA(isA<RangeError>()));
  });

  test('환자 최신 상태에는 실제 활력징후 값 또는 입력 상태를 표시한다', () {
    const PatientTransportSummary summary = PatientTransportSummary(
      ageLabel: '나이 확인 불가',
      sexLabel: '여성',
      primarySymptomLabel: '의식 변화',
      preKtasLabel: 'Pre-KTAS 2',
      avpuLabel: 'A',
      bloodPressureStateLabel: '환자 거부',
      pulseStateLabel: '측정 불가 (사유: 장비 오류)',
      respiratoryRateStateLabel: '환자 거부',
      temperatureStateLabel: '측정 불가 (사유: 환자 상태)',
      oxygenSaturationStateLabel: '환자 거부',
    );

    expect(summary.bloodPressureDisplay, '환자 거부');
    expect(summary.pulseDisplay, '측정 불가 (사유: 장비 오류)');
    expect(summary.temperatureDisplay, '측정 불가 (사유: 환자 상태)');

    final PatientTransportSummary updated = summary.copyWithVitals(
      systolic: 120,
      diastolic: 80,
      pulse: 72,
      respiratoryRate: 16,
      temperature: 36.5,
      oxygenSaturation: 98,
      measuredAt: DateTime(2026, 8, 4, 18, 2),
    );
    expect(updated.bloodPressureDisplay, '120/80 mmHg');
    expect(updated.pulseDisplay, '72 bpm');
    expect(updated.temperatureDisplay, '36.5°C');
  });

  test('수락·측정 시각은 초 단위까지 표시한다', () {
    expect(
      formatClinicalTime(DateTime(2026, 8, 4, 18, 2, 7)),
      '08.04 18:02:07',
    );
  });

  test('목 병원 탐색은 1분 미응답마다 반경을 10km 확대한다', () async {
    final MockHospitalSearchDataSource dataSource =
        MockHospitalSearchDataSource();
    final progress = await dataSource.getProgress(
      HospitalSearchSession(
        requestId: 'REQ-RADIUS-TEST',
        startedAt: DateTime.now().subtract(const Duration(seconds: 61)),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );

    expect(progress.currentRadiusKm, 20);
    expect(progress.elapsedSeconds, greaterThanOrEqualTo(61));
  });
}

class _InMemoryAppGuideRepository implements AppGuideRepository {
  final Set<String> _seenUsernames = <String>{};

  @override
  Future<void> markGuideSeen(String username) async {
    _seenUsernames.add(_normalized(username));
  }

  @override
  Future<bool> shouldShowGuide(String username) async {
    return !_seenUsernames.contains(_normalized(username));
  }

  String _normalized(String username) => username.trim().toLowerCase();
}

class _AuthenticatedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      user: AuthUser(
        username: MockAuthDataSource.mockUsername,
        displayName: '김민준',
        organizationName: '강동소방서 3구급대',
        role: UserRole.paramedic,
        callbackContact: MockAuthDataSource.mockCallbackContact,
        consentRecord: PrivacyConsentRecord(
          collectionUseVersion: MockAuthDataSource.collectionUseConsentVersion,
          hospitalProvisionVersion:
              MockAuthDataSource.hospitalProvisionConsentVersion,
          acceptedAt: DateTime(2026, 8, 1, 9),
        ),
      ),
    );
  }
}
