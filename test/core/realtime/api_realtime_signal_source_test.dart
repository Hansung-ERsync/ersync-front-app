import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/network/authenticated_request.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/core/realtime/api_realtime_signal_source.dart';
import 'package:er_sync/core/realtime/realtime_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('연결 및 갱신 SSE 프레임을 실시간 신호로 변환한다', () async {
    late RequestOptions captured;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured = request;
        return ResponseBody.fromString(
          ':state must be fetched from API\n'
          'event: connected\n'
          '\n'
          'id: EVENT-1\n'
          'event: update\n'
          'data: ${jsonEncode(<String, Object?>{'eventId': 'EVENT-1', 'type': 'HOSPITAL_OFFER_RESPONDED', 'aggregateType': 'TRANSPORT_REQUEST', 'aggregateId': 'REQUEST-1', 'occurredAt': '2026-08-05T06:00:00Z'})}\n'
          '\n',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/event-stream'],
          },
        );
      });

    final List<RealtimeSignal> signals = await ApiRealtimeSignalSource(
      dio,
    ).connectOnce().toList();

    expect(captured.uri.path, '/api/v1/realtime/events');
    expect(captured.headers[Headers.acceptHeader], 'text/event-stream');
    expect(captured.extra[NetworkRequestExtraKeys.requiresAuth], isTrue);
    expect(signals, hasLength(2));
    expect(signals.first.kind, RealtimeSignalKind.connected);
    expect(signals.last.kind, RealtimeSignalKind.update);
    expect(signals.last.eventId, 'EVENT-1');
    expect(signals.last.type, 'HOSPITAL_OFFER_RESPONDED');
    expect(signals.last.aggregateId, 'REQUEST-1');
    expect(signals.last.occurredAt, DateTime.utc(2026, 8, 5, 6));
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions request) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);

  @override
  void close({bool force = false}) {}
}
