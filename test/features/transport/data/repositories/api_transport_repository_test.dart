import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_progress.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/assessment_enums.dart';
import 'package:er_sync/features/transport/data/repositories/api_transport_repository.dart';
import 'package:er_sync/features/transport/domain/entities/in_transit_clinical_updates.dart';
import 'package:er_sync/features/transport/domain/entities/active_transport_recovery.dart';
import 'package:er_sync/features/transport/domain/entities/recent_transport.dart';
import 'package:er_sync/features/transport/domain/entities/transport_location_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목적지 선택 전 취소 이력은 숨기고 목적지가 있던 취소만 표시한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        expect(request.uri.queryParameters['view'], 'RECENT');
        return _jsonResponse(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'transportRequestId': 'REQUEST-1',
              'status': 'CANCELLED',
              'hospitalName': null,
              'createdAt': '2026-08-05T01:00:00Z',
              'statusUpdatedAt': '2026-08-05T01:10:00Z',
              'cancelledAt': '2026-08-05T01:10:00Z',
              'cancellationReason': 'OTHER',
            },
            <String, Object?>{
              'transportRequestId': 'REQUEST-2',
              'status': 'CANCELLED',
              'hospitalName': '한양대학교병원',
              'createdAt': '2026-08-05T01:00:00Z',
              'statusUpdatedAt': '2026-08-05T01:10:00Z',
              'cancelledAt': '2026-08-05T01:10:00Z',
              'cancellationReason': 'OTHER',
            },
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        });
      });

    final List<RecentTransport> result = await ApiTransportRepository(
      dio,
    ).getRecentTransports();

    expect(result, hasLength(1));
    expect(result.single.requestId, 'REQUEST-2');
    expect(result.single.handoffStatus, HandoffStatus.cancelled);
    expect(result.single.hospitalDisplayName, '한양대학교병원');
  });

  test('OTHER 취소 상세와 안정적인 멱등성 키를 전송한다', () async {
    late RequestOptions captured;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured = request;
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-1',
          'status': 'CANCELLED',
          'reason': 'OTHER',
          'detail': '현장 처치 후 이송 불필요',
          'cancelledAt': '2026-08-05T01:10:00Z',
          'idempotentReplay': false,
        });
      });

    await ApiTransportRepository(dio).cancelRequest(
      'REQUEST-1',
      const TransportCancellation(
        reason: TransportCancellationReason.other,
        detail: '  현장 처치 후 이송 불필요  ',
      ),
    );

    expect(captured.headers['Idempotency-Key'], 'cancel-REQUEST-1');
    expect(_requestJson(captured), <String, Object?>{
      'reason': 'OTHER',
      'detail': '현장 처치 후 이송 불필요',
    });
  });

  test('이송 중 의식·Pre-KTAS·처치 변경을 임상 업데이트 API로 전송한다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        return _jsonResponse(<String, Object?>{}, statusCode: 201);
      });
    final ApiTransportRepository repository = ApiTransportRepository(dio);
    final DateTime observedAt = DateTime.utc(2026, 8, 5, 1, 2, 3);
    final DateTime assessedAt = DateTime.utc(2026, 8, 5, 1, 3, 4);
    final DateTime performedAt = DateTime.utc(2026, 8, 5, 1, 4, 5);
    final DateTime enteredAt = DateTime.utc(2026, 8, 5, 1, 5, 6);

    await repository.addConsciousnessUpdate(
      'REQUEST-1',
      InTransitConsciousnessUpdate(
        avpu: AvpuLevel.unassessable,
        unassessableReason: UnassessableReason.other,
        unassessableDetail: '  안면 외상으로 평가 어려움  ',
        observedAt: observedAt,
        enteredAt: enteredAt,
      ),
    );
    await repository.addPreKtasUpdate(
      'REQUEST-1',
      InTransitPreKtasUpdate(
        classificationStatus: ClassificationStatus.completed,
        level: 2,
        assessedAt: assessedAt,
        standardVersion: 'DEV_UNCONFIRMED',
        enteredAt: enteredAt,
      ),
    );
    await repository.addTreatmentUpdate(
      'REQUEST-1',
      InTransitTreatmentUpdate(
        type: TreatmentType.cpr,
        attemptResult: TreatmentAttemptResult.ongoing,
        details: const <String, Object?>{'currentStatus': '진행 중'},
        performedAt: performedAt,
        enteredAt: enteredAt,
      ),
    );

    expect(captured, hasLength(3));

    expect(
      captured[0].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/consciousness',
    );
    expect(
      captured[0].headers['Idempotency-Key'],
      'consciousness-REQUEST-1-${observedAt.microsecondsSinceEpoch}',
    );
    expect(_requestJson(captured[0]), <String, Object?>{
      'avpu': 'UNASSESSABLE',
      'unassessableReason': 'OTHER',
      'unassessableDetail': '안면 외상으로 평가 어려움',
      'observedAt': observedAt.toIso8601String(),
      'enteredAt': enteredAt.toIso8601String(),
    });

    expect(
      captured[1].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/pre-ktas',
    );
    expect(
      captured[1].headers['Idempotency-Key'],
      'prektas-REQUEST-1-${assessedAt.microsecondsSinceEpoch}',
    );
    expect(_requestJson(captured[1]), <String, Object?>{
      'classificationStatus': 'COMPLETED',
      'level': 2,
      'exceptionReason': null,
      'exceptionDetail': null,
      'assessedAt': assessedAt.toIso8601String(),
      'standardVersion': 'DEV_UNCONFIRMED',
      'enteredAt': enteredAt.toIso8601String(),
    });

    expect(
      captured[2].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/treatments',
    );
    expect(
      captured[2].headers['Idempotency-Key'],
      'treatment-REQUEST-1-CPR-${performedAt.microsecondsSinceEpoch}',
    );
    expect(_requestJson(captured[2]), <String, Object?>{
      'type': 'CPR',
      'attemptResult': 'ONGOING',
      'details': <String, Object?>{
        'currentStatus': '진행 중',
        'startedAt': performedAt.toIso8601String(),
      },
      'performedAt': performedAt.toIso8601String(),
      'enteredAt': enteredAt.toIso8601String(),
    });
  });

  test('이송 중 현재 위치와 촬영 시각을 PUT으로 전송한다', () async {
    late RequestOptions captured;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured = request;
        return _jsonResponse(<String, Object?>{});
      });
    final DateTime capturedAt = DateTime.utc(2026, 8, 6, 6, 30, 10);

    await ApiTransportRepository(dio).updateLocation(
      'REQUEST-1',
      TransportLocationUpdate(
        latitude: 37.5665,
        longitude: 126.978,
        capturedAt: capturedAt,
      ),
      'location-command-1',
    );

    expect(captured.method, 'PUT');
    expect(captured.uri.path, '/api/v1/transport-requests/REQUEST-1/location');
    expect(captured.headers['Idempotency-Key'], 'location-command-1');
    expect(_requestJson(captured), <String, Object>{
      'latitude': 37.5665,
      'longitude': 126.978,
      'capturedAt': capturedAt.toIso8601String(),
    });
  });

  test('인계 확인 대기 중인 이송은 메인에서 자동으로 다시 열지 않는다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        return _jsonResponse(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'transportRequestId': 'REQUEST-HANDOFF-PENDING',
              'status': 'HANDOFF_REQUESTED',
              'hospitalName': '서울시청 테스트병원',
              'createdAt': '2026-08-06T06:00:00Z',
              'statusUpdatedAt': '2026-08-06T06:10:00Z',
            },
          ],
        });
      });

    final ActiveTransportRecovery? recovery = await ApiTransportRepository(
      dio,
    ).recoverActiveTransport();

    expect(recovery, isNull);
    expect(captured, hasLength(1));
    expect(captured.single.uri.path, '/api/v1/transport-requests');
  });

  test('ACTIVE 목록과 상세·병원 검색으로 이동 중 화면을 복구한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        if (request.uri.path == '/api/v1/transport-requests' &&
            request.uri.queryParameters['view'] == 'ACTIVE') {
          return _jsonResponse(<String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'transportRequestId': 'REQUEST-ACTIVE',
                'status': 'EN_ROUTE',
                'hospitalName': '한양대학교병원',
                'createdAt': '2026-08-06T06:00:00Z',
                'statusUpdatedAt': '2026-08-06T06:10:00Z',
              },
            ],
          });
        }
        if (request.uri.path == '/api/v1/transport-requests/REQUEST-ACTIVE') {
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-ACTIVE',
            'status': 'EN_ROUTE',
            'patient': <String, Object?>{
              'ageStatus': 'ESTIMATED',
              'ageYears': 45,
              'sex': 'MALE',
            },
            'incident': <String, Object?>{'primarySymptom': 'CHEST_PAIN'},
            'latestSnapshot': <String, Object?>{
              'preKtas': <String, Object?>{
                'classificationStatus': 'COMPLETED',
                'level': 2,
                'standardVersion': 'DEV_UNCONFIRMED',
              },
              'consciousness': <String, Object?>{'avpu': 'A'},
              'vitalSigns': <String, Object?>{
                'measuredAt': '2026-08-06T06:09:00Z',
                'measurements': <Object?>[
                  <String, Object?>{
                    'type': 'BLOOD_PRESSURE',
                    'state': 'VALUE',
                    'primaryValue': 120,
                    'secondaryValue': 80,
                  },
                  <String, Object?>{
                    'type': 'PULSE',
                    'state': 'VALUE',
                    'primaryValue': 82,
                  },
                  <String, Object?>{
                    'type': 'RESPIRATORY_RATE',
                    'state': 'MEASUREMENT_UNAVAILABLE',
                  },
                  <String, Object?>{
                    'type': 'TEMPERATURE',
                    'state': 'PATIENT_REFUSED',
                  },
                  <String, Object?>{
                    'type': 'SPO2',
                    'state': 'VALUE',
                    'primaryValue': 97,
                  },
                ],
              },
            },
          });
        }
        if (request.uri.path ==
            '/api/v1/transport-requests/REQUEST-ACTIVE/hospital-search') {
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-ACTIVE',
            'status': 'EN_ROUTE',
            'currentDestinationOfferId': 'OFFER-1',
            'offers': <Object?>[
              <String, Object?>{
                'offerId': 'OFFER-1',
                'hospitalName': '한양대학교병원',
                'hospitalAddress': '서울특별시 성동구 왕십리로 222-1',
                'hospitalContact': '02-2290-8119',
                'currentDestination': true,
                'routeDistanceMeters': 8400,
                'etaSeconds': 1080,
                'respondedAt': '2026-08-06T06:05:00Z',
              },
            ],
          });
        }
        throw StateError('예상하지 못한 요청: ${request.uri}');
      });

    final ActiveTransportRecovery? recovery = await ApiTransportRepository(
      dio,
    ).recoverActiveTransport();

    expect(recovery?.transportSession?.requestId, 'REQUEST-ACTIVE');
    expect(recovery?.transportSession?.requestStatus, 'EN_ROUTE');
    expect(recovery?.transportSession?.destination.name, '한양대학교병원');
    expect(
      recovery?.transportSession?.destination.address,
      '서울특별시 성동구 왕십리로 222-1',
    );
    expect(recovery?.transportSession?.patientSummary.ageLabel, '45세 추정');
    expect(
      recovery?.transportSession?.patientSummary.bloodPressureDisplay,
      '120/80 mmHg',
    );
    expect(
      recovery?.transportSession?.patientSummary.respiratoryRateDisplay,
      '측정 불가',
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

Map<String, dynamic> _requestJson(RequestOptions request) {
  final Object? data = request.data;
  if (data is Map<dynamic, dynamic>) {
    return Map<String, dynamic>.from(data);
  }
  throw StateError('JSON 요청 본문이 아닙니다: $data');
}

ResponseBody _jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
