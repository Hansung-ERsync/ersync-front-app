import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/app_exception.dart';

class PendingTransportCommand {
  const PendingTransportCommand({
    required this.operation,
    required this.method,
    required this.path,
    required this.idempotencyKey,
    this.body,
  });

  final String operation;
  final String method;
  final String path;
  final String idempotencyKey;
  final Map<String, Object?>? body;

  Map<String, Object?> toJson() => <String, Object?>{
    'operation': operation,
    'method': method,
    'path': path,
    'idempotencyKey': idempotencyKey,
    'body': body,
  };

  factory PendingTransportCommand.fromJson(Map<String, Object?> json) {
    final Object? operation = json['operation'];
    final Object? method = json['method'];
    final Object? path = json['path'];
    final Object? idempotencyKey = json['idempotencyKey'];
    final Object? rawBody = json['body'];
    if (operation is! String ||
        method is! String ||
        path is! String ||
        idempotencyKey is! String ||
        (rawBody != null && rawBody is! Map<dynamic, dynamic>)) {
      throw const FormatException('Invalid pending transport command.');
    }
    return PendingTransportCommand(
      operation: operation,
      method: method,
      path: path,
      idempotencyKey: idempotencyKey,
      body: rawBody == null
          ? null
          : Map<String, Object?>.from(rawBody as Map<dynamic, dynamic>),
    );
  }
}

abstract interface class PendingTransportCommandStore {
  Future<PendingTransportCommand?> read(String operation);

  Future<List<PendingTransportCommand>> readAll();

  Future<void> write(PendingTransportCommand command);

  Future<void> remove(String operation);
}

class SecurePendingTransportCommandStore
    implements PendingTransportCommandStore {
  SecurePendingTransportCommandStore({
    required String accountId,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storageKey = 'ersync.transport.pending-commands.$accountId',
       _storage = storage;

  final String _storageKey;
  final FlutterSecureStorage _storage;
  Map<String, PendingTransportCommand>? _cache;
  Future<void> _mutation = Future<void>.value();

  @override
  Future<PendingTransportCommand?> read(String operation) async {
    await _mutation;
    await _load();
    return _cache![operation];
  }

  @override
  Future<List<PendingTransportCommand>> readAll() async {
    await _mutation;
    await _load();
    return List<PendingTransportCommand>.unmodifiable(_cache!.values);
  }

  @override
  Future<void> write(PendingTransportCommand command) => _enqueue(() async {
    await _load();
    _cache![command.operation] = command;
    await _persist();
  });

  @override
  Future<void> remove(String operation) => _enqueue(() async {
    await _load();
    if (_cache!.remove(operation) != null) {
      await _persist();
    }
  });

  Future<void> _enqueue(Future<void> Function() mutation) {
    final Future<void> operation = _mutation.then((_) => mutation());
    _mutation = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _load() async {
    if (_cache != null) {
      return;
    }
    try {
      final String? encoded = await _storage.read(key: _storageKey);
      if (encoded == null || encoded.isEmpty) {
        _cache = <String, PendingTransportCommand>{};
        return;
      }
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) {
        throw const FormatException('Invalid pending command list.');
      }
      final Map<String, PendingTransportCommand> commands =
          <String, PendingTransportCommand>{};
      for (final Object? raw in decoded) {
        if (raw is! Map<dynamic, dynamic>) {
          throw const FormatException('Invalid pending command.');
        }
        final PendingTransportCommand command =
            PendingTransportCommand.fromJson(Map<String, Object?>.from(raw));
        commands[command.operation] = command;
      }
      _cache = commands;
    } on PlatformException {
      throw const AppException(
        '미완료 이송 명령을 안전하게 불러올 수 없습니다.',
        code: 'COMMAND_STORAGE_ERROR',
      );
    } on Object {
      _cache = <String, PendingTransportCommand>{};
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      if (_cache!.isEmpty) {
        await _storage.delete(key: _storageKey);
        return;
      }
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(
          _cache!.values
              .map((PendingTransportCommand value) => value.toJson())
              .toList(growable: false),
        ),
      );
    } on PlatformException {
      throw const AppException(
        '미완료 이송 명령을 안전하게 저장할 수 없습니다.',
        code: 'COMMAND_STORAGE_ERROR',
      );
    }
  }
}

class InMemoryPendingTransportCommandStore
    implements PendingTransportCommandStore {
  final Map<String, PendingTransportCommand> _commands =
      <String, PendingTransportCommand>{};

  @override
  Future<PendingTransportCommand?> read(String operation) async =>
      _commands[operation];

  @override
  Future<List<PendingTransportCommand>> readAll() async =>
      List<PendingTransportCommand>.unmodifiable(_commands.values);

  @override
  Future<void> write(PendingTransportCommand command) async {
    _commands[command.operation] = command;
  }

  @override
  Future<void> remove(String operation) async {
    _commands.remove(operation);
  }
}
