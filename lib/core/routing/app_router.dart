import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/sign_up_account_page.dart';
import '../../features/auth/presentation/pages/sign_up_code_page.dart';
import '../../features/auth/presentation/pages/sign_up_success_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/hospital_search/domain/entities/hospital_search_session.dart';
import '../../features/hospital_search/presentation/pages/hospital_search_page.dart';
import '../../features/patient_assessment/presentation/pages/patient_assessment_page.dart';
import '../../features/settings/presentation/pages/app_guide_page.dart';
import '../../features/settings/presentation/pages/handoff_history_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/transport/domain/entities/transport_session.dart';
import '../../features/transport/presentation/pages/transport_in_progress_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => LoginPage(
          initialErrorMessage: state.extra is String
              ? state.extra! as String
              : null,
        ),
      ),
      GoRoute(
        path: '/sign-up/code',
        name: 'signUpCode',
        builder: (context, state) => const SignUpCodePage(),
      ),
      GoRoute(
        path: '/sign-up/account',
        name: 'signUpAccount',
        builder: (context, state) => const SignUpAccountPage(),
      ),
      GoRoute(
        path: '/sign-up/success',
        name: 'signUpSuccess',
        builder: (context, state) => const SignUpSuccessPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/patient-assessment',
        name: 'patientAssessment',
        builder: (context, state) => const PatientAssessmentPage(),
      ),
      GoRoute(
        path: '/transport-requests/:requestId/searching',
        name: 'hospitalSearch',
        builder: (context, state) {
          final Object? extra = state.extra;
          final HospitalSearchSession session = extra is HospitalSearchSession
              ? extra
              : HospitalSearchSession(
                  requestId: state.pathParameters['requestId']!,
                  startedAt: DateTime.now(),
                  initialRadiusKm: 10,
                  radiusStepKm: 10,
                  expansionIntervalSeconds: 60,
                  maximumRadiusKm: 100,
                );
          return HospitalSearchPage(session: session);
        },
      ),
      GoRoute(
        path: '/transport-requests/:requestId/in-progress',
        name: 'transportInProgress',
        builder: (context, state) {
          final Object? extra = state.extra;
          if (extra is! TransportSession) {
            return const HomePage();
          }
          return TransportInProgressPage(session: extra);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/app-guide',
        name: 'appGuide',
        builder: (context, state) => const AppGuidePage(),
      ),
      GoRoute(
        path: '/handoff-history',
        name: 'handoffHistory',
        builder: (context, state) => const HandoffHistoryPage(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
