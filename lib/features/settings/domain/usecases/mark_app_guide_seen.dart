import '../repositories/app_guide_repository.dart';

class MarkAppGuideSeen {
  const MarkAppGuideSeen(this._repository);

  final AppGuideRepository _repository;

  Future<void> call(String username) {
    return _repository.markGuideSeen(username);
  }
}
