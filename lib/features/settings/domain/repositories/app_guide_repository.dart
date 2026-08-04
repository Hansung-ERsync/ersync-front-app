abstract interface class AppGuideRepository {
  Future<bool> shouldShowGuide(String username);

  Future<void> markGuideSeen(String username);
}
