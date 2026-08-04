import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/app_guide_preferences_data_source.dart';
import '../../data/repositories/local_app_guide_repository.dart';
import '../../domain/repositories/app_guide_repository.dart';
import '../../domain/usecases/mark_app_guide_seen.dart';
import '../../domain/usecases/should_show_app_guide.dart';

final Provider<AppGuidePreferencesDataSource>
appGuidePreferencesDataSourceProvider = Provider<AppGuidePreferencesDataSource>(
  (Ref ref) => AppGuidePreferencesDataSource(),
);

final Provider<AppGuideRepository> appGuideRepositoryProvider =
    Provider<AppGuideRepository>(
      (Ref ref) => LocalAppGuideRepository(
        ref.watch(appGuidePreferencesDataSourceProvider),
      ),
    );

final Provider<ShouldShowAppGuide> shouldShowAppGuideProvider =
    Provider<ShouldShowAppGuide>(
      (Ref ref) => ShouldShowAppGuide(ref.watch(appGuideRepositoryProvider)),
    );

final Provider<MarkAppGuideSeen> markAppGuideSeenProvider =
    Provider<MarkAppGuideSeen>(
      (Ref ref) => MarkAppGuideSeen(ref.watch(appGuideRepositoryProvider)),
    );
