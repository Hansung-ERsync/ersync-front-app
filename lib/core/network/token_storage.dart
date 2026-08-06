import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/app_exception.dart';
import 'auth_tokens.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const String _storageKey = 'ersync.auth.tokens';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final String? encoded;
    try {
      encoded = await _storage.read(key: _storageKey);
    } on PlatformException {
      throw const AppException(
        '저장된 로그인 정보를 불러올 수 없습니다.',
        code: 'TOKEN_STORAGE_ERROR',
      );
    }
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        await clear();
        return null;
      }
      return AuthTokens.fromStorageJson(decoded);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(tokens.toStorageJson()),
      );
    } on PlatformException {
      throw const AppException(
        '로그인 정보를 안전하게 저장할 수 없습니다.',
        code: 'TOKEN_STORAGE_ERROR',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _storageKey);
    } on PlatformException {
      throw const AppException(
        '저장된 로그인 정보를 삭제할 수 없습니다.',
        code: 'TOKEN_STORAGE_ERROR',
      );
    }
  }
}

class InMemoryTokenStorage implements TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
