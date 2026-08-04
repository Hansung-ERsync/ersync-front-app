import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/datasources/mock_auth_data_source.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/invitation_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/validate_invitation_code.dart';

final Provider<MockAuthDataSource> mockAuthDataSourceProvider =
    Provider<MockAuthDataSource>((Ref ref) => MockAuthDataSource());

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => MockAuthRepository(ref.watch(mockAuthDataSourceProvider)),
    );

final Provider<ValidateInvitationCode> validateInvitationCodeProvider =
    Provider<ValidateInvitationCode>(
      (Ref ref) => ValidateInvitationCode(ref.watch(authRepositoryProvider)),
    );

final Provider<SignUp> signUpProvider = Provider<SignUp>(
  (Ref ref) => SignUp(ref.watch(authRepositoryProvider)),
);

final Provider<SignIn> signInProvider = Provider<SignIn>(
  (Ref ref) => SignIn(ref.watch(authRepositoryProvider)),
);

final NotifierProvider<AuthViewModel, AuthState> authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void startSignUp() {
    state = AuthState(
      user: state.user,
      registeredUsername: state.registeredUsername,
    );
  }

  Future<bool> validateInvitationCode(String code) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final InvitationInfo invitation = await ref.read(
        validateInvitationCodeProvider,
      )(code);
      state = state.copyWith(
        isLoading: false,
        invitation: invitation,
        clearError: true,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> signUp({
    required String displayName,
    required String username,
    required String password,
    required String callbackContact,
    required bool collectionUseConsent,
    required bool hospitalProvisionConsent,
  }) async {
    final InvitationInfo? invitation = state.invitation;
    if (invitation == null) {
      state = state.copyWith(errorMessage: '가입 코드를 먼저 확인해주세요.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref.read(signUpProvider)(
        invitation: invitation,
        displayName: displayName,
        username: username,
        password: password,
        callbackContact: callbackContact,
        collectionUseConsent: collectionUseConsent,
        hospitalProvisionConsent: hospitalProvisionConsent,
      );
      state = state.copyWith(
        isLoading: false,
        registeredUsername: username.trim(),
        clearError: true,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final AuthUser user = await ref.read(signInProvider)(
        username: username,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user, clearError: true);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  void signOut() {
    state = const AuthState();
  }
}

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.invitation,
    this.user,
    this.errorMessage,
    this.registeredUsername,
  });

  final bool isLoading;
  final InvitationInfo? invitation;
  final AuthUser? user;
  final String? errorMessage;
  final String? registeredUsername;

  AuthState copyWith({
    bool? isLoading,
    InvitationInfo? invitation,
    AuthUser? user,
    String? errorMessage,
    String? registeredUsername,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      invitation: invitation ?? this.invitation,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      registeredUsername: registeredUsername ?? this.registeredUsername,
    );
  }
}
