import '../../domain/repositories/app_guide_repository.dart';
import '../datasources/app_guide_preferences_data_source.dart';

class LocalAppGuideRepository implements AppGuideRepository {
  const LocalAppGuideRepository(this._dataSource);

  final AppGuidePreferencesDataSource _dataSource;

  @override
  Future<void> markGuideSeen(String username) {
    return _dataSource.markGuideSeen(username);
  }

  @override
  Future<bool> shouldShowGuide(String username) async {
    return !(await _dataSource.hasSeenGuide(username));
  }
}
