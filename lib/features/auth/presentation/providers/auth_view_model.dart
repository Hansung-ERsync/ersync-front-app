import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_providers.dart';
import '../../data/apis/auth_api.dart';
import '../../data/datasources/mock_auth_data_source.dart';
import '../../data/repositories/api_auth_repository.dart';
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

final Provider<AuthRepository> apiAuthRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => ApiAuthRepository(
        AuthApi(ref.watch(dioProvider)),
        ref.watch(tokenStorageProvider),
      ),
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

  Future<bool> restoreSession() async {
    if (state.user != null || state.isRestoringSession) {
      return state.user != null;
    }
    state = state.copyWith(isRestoringSession: true, clearError: true);
    try {
      final AuthUser? user = await ref
          .read(authRepositoryProvider)
          .restoreSession();
      state = state.copyWith(
        isRestoringSession: false,
        user: user,
        clearUser: user == null,
        clearError: true,
      );
      return user != null;
    } on AppException catch (error) {
      state = state.copyWith(
        isRestoringSession: false,
        errorMessage: error.message,
        errorCode: error.code,
        traceId: error.traceId,
      );
      return false;
    }
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        errorCode: error.code,
        traceId: error.traceId,
      );
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
        clearInvitation: true,
        clearError: true,
      );
      return true;
    } on AppException catch (error) {
      final bool invitationUnavailable = const <String>{
        'INVITATION_001',
        'INVITATION_002',
        'INVITATION_003',
        'INVITATION_004',
      }.contains(error.code);
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        errorCode: error.code,
        traceId: error.traceId,
        clearInvitation: invitationUnavailable,
      );
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        errorCode: error.code,
        traceId: error.traceId,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState();
  }
}

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isRestoringSession = false,
    this.invitation,
    this.user,
    this.errorMessage,
    this.errorCode,
    this.traceId,
    this.registeredUsername,
  });

  final bool isLoading;
  final bool isRestoringSession;
  final InvitationInfo? invitation;
  final AuthUser? user;
  final String? errorMessage;
  final String? errorCode;
  final String? traceId;
  final String? registeredUsername;

  AuthState copyWith({
    bool? isLoading,
    bool? isRestoringSession,
    InvitationInfo? invitation,
    AuthUser? user,
    String? errorMessage,
    String? errorCode,
    String? traceId,
    String? registeredUsername,
    bool clearError = false,
    bool clearInvitation = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      invitation: clearInvitation ? null : invitation ?? this.invitation,
      user: clearUser ? null : user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      traceId: clearError ? null : traceId ?? this.traceId,
      registeredUsername: registeredUsername ?? this.registeredUsername,
    );
  }
}
