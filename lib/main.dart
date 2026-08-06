import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/realtime/realtime_providers.dart';
import 'features/auth/presentation/providers/auth_view_model.dart';
import 'features/hospital_search/presentation/providers/hospital_search_view_model.dart';
import 'features/patient_assessment/presentation/providers/patient_assessment_view_model.dart';
import 'features/transport/presentation/providers/transport_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith(
          (Ref ref) => ref.watch(apiAuthRepositoryProvider),
        ),
        patientAssessmentRepositoryProvider.overrideWith(
          (Ref ref) => ref.watch(apiPatientAssessmentRepositoryProvider),
        ),
        hospitalSearchRepositoryProvider.overrideWith(
          (Ref ref) => ref.watch(apiHospitalSearchRepositoryProvider),
        ),
        transportRepositoryProvider.overrideWith(
          (Ref ref) => ref.watch(apiTransportRepositoryProvider),
        ),
        realtimeSignalSourceProvider.overrideWith(
          (Ref ref) => ref.watch(apiRealtimeSignalSourceProvider),
        ),
      ],
      child: const ErSyncApp(),
    ),
  );
}
