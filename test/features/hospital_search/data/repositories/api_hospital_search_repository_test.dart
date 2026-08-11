import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/features/hospital_search/data/repositories/api_hospital_search_repository.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('취소된 탐색은 endedAt에서 시간을 멈추고 종료 상태를 반환한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        expect(
          request.uri.path,
          '/api/v1/transport-requests/REQUEST-1/hospital-search',
        );
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-1',
          'status': 'CANCELLED',
          'currentDestinationOfferId': null,
          'currentAttempt': <String, Object?>{
            'dispatchAttemptId': 'ATTEMPT-1',
            'number': 1,
            'status': 'CANCELLED',
            'currentRadiusKm': 100,
            'candidateShortage': false,
            'nextExpansionAt': null,
            'startedAt': '2026-08-05T06:00:00Z',
            'endedAt': '2026-08-05T06:05:00Z',
          },
          'exhaustionReason': null,
          'offers': <Object?>[],
          'serverNow': '2026-08-05T07:00:00Z',
        });
      });

    final progress = await ApiHospitalSearchRepository(dio).getProgress(
      HospitalSearchSession(
        requestId: 'REQUEST-1',
        startedAt: DateTime.utc(2026, 8, 5, 6),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );

    expect(progress.requestStatus, 'CANCELLED');
    expect(progress.isCancelled, isTrue);
    expect(progress.isElapsedRunning, isFalse);
    expect(progress.elapsedSeconds, 5 * 60);
  });

  test('후보 소진 상태는 요청 전체 경과 시간을 계속 계산한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-EXHAUSTED',
          'status': 'CANDIDATES_EXHAUSTED',
          'currentDestinationOfferId': null,
          'currentAttempt': <String, Object?>{
            'dispatchAttemptId': 'ATTEMPT-EXHAUSTED',
            'number': 1,
            'status': 'CANDIDATES_EXHAUSTED',
            'currentRadiusKm': 100,
            'candidateShortage': true,
            'nextExpansionAt': null,
            'startedAt': '2026-08-05T06:00:00Z',
            'endedAt': '2026-08-05T06:00:01Z',
          },
          'exhaustionReason': 'NO_CANDIDATES',
          'offers': <Object?>[],
          'serverNow': '2026-08-05T06:05:00Z',
        });
      });

    final progress = await ApiHospitalSearchRepository(dio).getProgress(
      HospitalSearchSession(
        requestId: 'REQUEST-EXHAUSTED',
        startedAt: DateTime.utc(2026, 8, 5, 6),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );

    expect(progress.requestStatus, 'CANDIDATES_EXHAUSTED');
    expect(progress.isElapsedRunning, isFalse);
    expect(progress.isExhausted, isTrue);
    expect(progress.candidateShortage, isTrue);
    expect(progress.exhaustionReason, 'NO_CANDIDATES');
    expect(progress.elapsedSeconds, 5 * 60);
  });

  test('병원 수락 후 목적지 선택 전까지 경과 시간을 계속 실행한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-ACCEPTED',
          'status': 'ACCEPTED_AVAILABLE',
          'currentDestinationOfferId': null,
          'currentAttempt': <String, Object?>{
            'dispatchAttemptId': 'ATTEMPT-ACCEPTED',
            'number': 1,
            'status': 'ACCEPTED_AVAILABLE',
            'currentRadiusKm': 100,
            'candidateShortage': false,
            'nextExpansionAt': null,
            'startedAt': '2026-08-05T06:00:00Z',
            'endedAt': null,
          },
          'exhaustionReason': null,
          'offers': <Object?>[
            <String, Object?>{
              'offerId': 'OFFER-ACCEPTED',
              'status': 'ACCEPTED',
              'hospitalName': '서울시청 테스트병원',
              'hospitalAddress': '서울특별시 중구 세종대로 110',
              'hospitalContact': '02-1234-5678',
              'straightLineDistanceMeters': 0,
              'routeDistanceMeters': null,
              'etaSeconds': null,
              'respondedAt': '2026-08-05T06:00:19Z',
            },
          ],
          'serverNow': '2026-08-05T06:05:00Z',
        });
      });

    final progress = await ApiHospitalSearchRepository(dio).getProgress(
      HospitalSearchSession(
        requestId: 'REQUEST-ACCEPTED',
        startedAt: DateTime.utc(2026, 8, 5, 6),
        initialRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumRadiusKm: 100,
      ),
    );

    expect(progress.requestStatus, 'ACCEPTED_AVAILABLE');
    expect(progress.isElapsedRunning, isTrue);
    expect(progress.elapsedSeconds, 5 * 60);
    expect(progress.acceptedHospitals.single.address, '서울특별시 중구 세종대로 110');
    expect(progress.acceptedHospitals.single.distanceLabel, '100m 미만');
    expect(progress.acceptedHospitals.single.etaLabel, isNull);
  });

  test('목적지 변경 명령과 후보 소진 재검색마다 새 멱등성 키를 사용한다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        return _jsonResponse(<String, Object?>{});
      });
    final ApiHospitalSearchRepository repository = ApiHospitalSearchRepository(
      dio,
    );

    await repository.selectDestination(
      'REQUEST-1',
      'OFFER-A',
      'destination-command-a1',
    );
    await repository.selectDestination(
      'REQUEST-1',
      'OFFER-B',
      'destination-command-b1',
    );
    await repository.selectDestination(
      'REQUEST-1',
      'OFFER-A',
      'destination-command-a2',
    );
    await repository.retrySearch('REQUEST-1', 'search-retry-command-1');

    final List<String> keys = captured
        .map(
          (RequestOptions request) =>
              request.headers['Idempotency-Key']! as String,
        )
        .toList();
    expect(keys.toSet(), hasLength(4));
    expect(keys, everyElement(matches(RegExp(r'^[A-Za-z0-9._:-]{8,100}$'))));
    expect(captured[0].data, <String, Object>{'offerId': 'OFFER-A'});
    expect(captured[1].data, <String, Object>{'offerId': 'OFFER-B'});
    expect(captured[2].data, <String, Object>{'offerId': 'OFFER-A'});
    expect(
      captured[3].uri.path,
      '/api/v1/transport-requests/REQUEST-1/dispatch-attempts',
    );
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

ResponseBody _jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
