import 'package:shared_preferences/shared_preferences.dart';

class AppGuidePreferencesDataSource {
  AppGuidePreferencesDataSource({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String guideVersion = 'ERSYNC_APP_GUIDE_1.0';

  final SharedPreferencesAsync _preferences;

  Future<bool> hasSeenGuide(String username) async {
    return await _preferences.getBool(_key(username)) ?? false;
  }

  Future<void> markGuideSeen(String username) {
    return _preferences.setBool(_key(username), true);
  }

  String _key(String username) {
    return 'app_guide_seen_${guideVersion}_${username.trim().toLowerCase()}';
  }
}
