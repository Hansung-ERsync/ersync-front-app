import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';
import '../../data/repositories/mock_home_repository.dart';
import '../../../transport/domain/entities/recent_transport.dart';
import '../../../transport/presentation/providers/transport_view_model.dart';
import '../../domain/repositories/home_repository.dart';

final Provider<HomeRepository> homeRepositoryProvider =
    Provider<HomeRepository>(
      (Ref ref) => MockHomeRepository(ref.watch(transportRepositoryProvider)),
    );

final StreamNotifierProvider<HomeViewModel, HomeViewState>
homeViewModelProvider = StreamNotifierProvider<HomeViewModel, HomeViewState>(
  HomeViewModel.new,
);

class HomeViewModel extends StreamNotifier<HomeViewState> {
  @override
  Stream<HomeViewState> build() async* {
    final AuthUser? user = ref.watch(
      authViewModelProvider.select((AuthState state) => state.user),
    );

    if (user == null) {
      throw const AppException('로그인이 필요합니다.');
    }

    await for (final List<RecentTransport> recentTransports
        in ref.watch(homeRepositoryProvider).watchRecentTransports()) {
      yield HomeViewState(user: user, recentTransports: recentTransports);
    }
  }
}

class HomeViewState {
  const HomeViewState({required this.user, required this.recentTransports});

  final AuthUser user;
  final List<RecentTransport> recentTransports;
}
