import '../repositories/app_guide_repository.dart';

class ShouldShowAppGuide {
  const ShouldShowAppGuide(this._repository);

  final AppGuideRepository _repository;

  Future<bool> call(String username) {
    return _repository.shouldShowGuide(username);
  }
}
