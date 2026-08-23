import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/authenticated_request.dart';
import 'realtime_signal.dart';
import 'realtime_signal_source.dart';

class ApiRealtimeSignalSource implements RealtimeSignalSource {
  ApiRealtimeSignalSource(
    this._dio, {
    List<Duration> reconnectDelays = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
  }) : _reconnectDelays = List<Duration>.unmodifiable(reconnectDelays);

  final Dio _dio;
  final List<Duration> _reconnectDelays;

  @override
  Stream<RealtimeSignal> watchSignals() async* {
    int failedConnectionCount = 0;
    while (true) {
      bool connected = false;
      try {
        await for (final RealtimeSignal signal in connectOnce()) {
          connected = true;
          failedConnectionCount = 0;
          yield signal;
        }
      } on Object {
        // REST fallback remains authoritative while this stream reconnects.
      }

      if (connected) {
        failedConnectionCount = 0;
      }
      final Duration delay = _reconnectDelay(failedConnectionCount);
      failedConnectionCount += 1;
      await Future<void>.delayed(delay);
    }
  }

  Stream<RealtimeSignal> connectOnce() async* {
    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      '/api/v1/realtime/events',
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        headers: const <String, Object>{
          Headers.acceptHeader: 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
        extra: const <String, Object>{
          NetworkRequestExtraKeys.requiresAuth: true,
        },
      ),
    );
    final ResponseBody? responseBody = response.data;
    if (responseBody == null) {
      throw StateError('SSE 응답 스트림이 없습니다.');
    }

    String? eventName;
    String? eventId;
    final List<String> dataLines = <String>[];
    await for (final String line
        in responseBody.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        final RealtimeSignal? signal = _toSignal(
          eventName: eventName,
          eventId: eventId,
          data: dataLines.join('\n'),
        );
        eventName = null;
        eventId = null;
        dataLines.clear();
        if (signal != null) {
          yield signal;
        }
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }

      final int separator = line.indexOf(':');
      final String field = separator < 0 ? line : line.substring(0, separator);
      String value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      switch (field) {
        case 'event':
          eventName = value;
        case 'id':
          eventId = value;
        case 'data':
          dataLines.add(value);
      }
    }

    final RealtimeSignal? finalSignal = _toSignal(
      eventName: eventName,
      eventId: eventId,
      data: dataLines.join('\n'),
    );
    if (finalSignal != null) {
      yield finalSignal;
    }
  }

  Duration _reconnectDelay(int failedConnectionCount) {
    if (_reconnectDelays.isEmpty) {
      return Duration.zero;
    }
    final int index = failedConnectionCount
        .clamp(0, _reconnectDelays.length - 1)
        .toInt();
    return _reconnectDelays[index];
  }

  RealtimeSignal? _toSignal({
    required String? eventName,
    required String? eventId,
    required String data,
  }) {
    if (eventName == 'connected') {
      return const RealtimeSignal.connected();
    }
    if (eventName != 'update' || data.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(data);
      if (decoded is! Map<dynamic, dynamic>) {
        return null;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      return RealtimeSignal(
        eventId: _string(json['eventId']) ?? eventId,
        type: _string(json['type']),
        aggregateId: _string(json['aggregateId']),
      );
    } on FormatException {
      return null;
    }
  }

  String? _string(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}
